--- Redirect |ui-messages| (|msg_show|) to the Juu notification subsystem.
--- Uses |vim.ui_attach()| with `ext_messages`; see |ui-messages| and |api-ui-events.txt|.
local config = require("juu.config")
local juu_notify = require("juu.notify").notify

local M = {}

M._initialized = false
M._ns = nil ---@type integer?

--- Dedupe / prefix chain: |msg_show| can emit a short line (e.g. quoted path) then the full "…written" line.
---@type { text: string, t: number }
local last_dedupe = { text = "", t = 0 }

--- Kinds we never route to notifications (interactive, cmdline-integrated, or ill-suited).
---@type table<string, true>
local default_exclude = {
  empty = true,
  search_count = true,
  search_cmd = true,
  wildlist = true,
  confirm = true,
  confirm_sub = true,
  list_cmd = true,
  number_prompt = true,
  return_prompt = true,
  completion = true,
  shell_cmd = true,
  shell_out = true,
  shell_ret = true,
  -- nvim_echo progress during :write often duplicates the final bufwrite line.
  progress = true,
}

---@param kind string
---@return integer
local function kind_to_level(kind)
  if kind == "emsg" or kind == "echoerr" or kind == "lua_error" or kind == "rpc_error" or kind == "shell_err" then
    return vim.log.levels.ERROR
  elseif kind == "wmsg" then
    return vim.log.levels.WARN
  end
  return vim.log.levels.INFO
end

---@param content table|nil
---@return string
local function content_to_string(content)
  if not content or #content == 0 then
    return ""
  end
  local parts = {}
  for _, chunk in ipairs(content) do
    if type(chunk) == "table" and type(chunk[2]) == "string" then
      parts[#parts + 1] = chunk[2]
    end
  end
  return table.concat(parts)
end

---@param t table
---@return boolean
local function is_luajit_list(t)
  if vim.islist then
    return vim.islist(t)
  end
  return vim.tbl_islist(t)
end

---@param cfg table
---@return table<string, true>
local function merge_exclude(cfg)
  local t = vim.deepcopy(default_exclude)
  local extra = cfg.exclude_kinds
  if type(extra) == "table" then
    if is_luajit_list(extra) then
      for _, k in ipairs(extra) do
        if type(k) == "string" then
          t[k] = true
        end
      end
    else
      for k, v in pairs(extra) do
        if v == false then
          t[k] = nil
        elseif v then
          t[k] = true
        end
      end
    end
  end
  return t
end

---@return "skip"|"new"|"supersede"
local function dedupe_action(text, ms)
  if ms == false then
    return "new"
  end
  local window = type(ms) == "number" and ms or 200
  local trimmed = vim.trim(text)
  if trimmed == "" then
    return "new"
  end
  local now = (vim.uv or vim.loop).now()
  local prev = last_dedupe.text
  local prev_t = last_dedupe.t

  if prev ~= "" and (now - prev_t) < window then
    if trimmed == prev then
      return "skip"
    end
    -- Second line extends the first (e.g. quoted path → path + "12L, 321B written")
    if #trimmed > #prev and trimmed:sub(1, #prev) == prev then
      last_dedupe.text = trimmed
      last_dedupe.t = now
      return "supersede"
    end
  end

  last_dedupe.text = trimmed
  last_dedupe.t = now
  return "new"
end

--- Quoted-path-only line often precedes the full |:write| summary; use one replace key for both.
---@param text string
---@return boolean
local function likely_write_prefix(text)
  local t = vim.trim(text)
  if t == "" or t:find("written") then
    return false
  end
  return t:match('^"[^"]+"%s*$') ~= nil
end

---@param kind string
---@param text string
---@param replace_last boolean
---@param id any
---@param cfg table
---@param use_write_chain boolean|nil Same key for path-only + full :write lines so the second replaces the first
local function notify_message(kind, text, replace_last, id, cfg, use_write_chain)
  local level = kind_to_level(kind)
  local opts = {
    group = "messages",
  }
  if use_write_chain then
    opts.key = "juu.msg:write_chain"
  elseif id ~= nil then
    opts.key = "juu.msg:id:" .. tostring(id)
  elseif replace_last then
    opts.key = "juu.msg:last"
  elseif kind == "bufwrite" then
    opts.key = "juu.msg:kind:bufwrite"
  end
  if cfg.opts then
    opts = vim.tbl_extend("force", opts, cfg.opts)
  end
  juu_notify(text, level, opts)
end

---@param cfg table
---@param kind string
---@param text string
---@param trigger string|nil
---@param exclude table<string, true>
---@return boolean redirect true if we should show as notify and consume the event
local function should_redirect(cfg, kind, text, trigger, exclude)
  if type(cfg.include_kinds) == "table" and #cfg.include_kinds > 0 then
    local allowed = false
    for _, k in ipairs(cfg.include_kinds) do
      if k == kind then
        allowed = true
        break
      end
    end
    if not allowed then
      return false
    end
  elseif exclude[kind] then
    return false
  end
  if cfg.filter and not cfg.filter(kind, text, trigger) then
    return false
  end
  if vim.trim(text) == "" then
    return false
  end
  return true
end

local function another_ui_handles_messages()
  return package.loaded["noice"] ~= nil
end

--- When |vim._core.ui2| is enabled, Neovim delivers |msg_show| to every |vim.ui_attach()| client.
--- ui2 draws into its cmd/msg buffers and juu notifies — same text twice. If we would redirect to
--- notify, skip ui2's |msg_show| implementation so only juu.notify runs.
---@param cfg table
---@param exclude table<string, true>
---@return boolean patched
local function patch_ui2_msg_show(cfg, exclude)
  local ok, ui2 = pcall(require, "vim._core.ui2")
  if not ok or not ui2 or ui2.cfg == nil or ui2.cfg.enable == false then
    return false
  end
  local ok2, msg = pcall(require, "vim._core.ui2.messages")
  if not ok2 or type(msg) ~= "table" or type(msg.msg_show) ~= "function" then
    return false
  end
  if msg._juu_skip_redirect_orig then
    return true
  end
  local orig = msg.msg_show
  msg._juu_skip_redirect_orig = orig
  function msg.msg_show(kind, content, replace_last, hist, append, id, trigger)
    if vim.g.juu_msg_redirect_suppress then
      return orig(kind, content, replace_last, hist, append, id, trigger)
    end
    kind = kind or ""
    local text = content_to_string(content)
    if not should_redirect(cfg, kind, text, trigger, exclude) then
      return orig(kind, content, replace_last, hist, append, id, trigger)
    end
    return
  end
  return true
end

---@param cfg table
local function attach(cfg)
  M._ns = vim.api.nvim_create_namespace("juu.messages")
  local exclude = merge_exclude(cfg)

  patch_ui2_msg_show(cfg, exclude)

  vim.ui_attach(M._ns, { ext_messages = true }, function(event, ...)
    if event == "msg_show" then
      local kind, content, replace_last, _, _, id, trigger = ...
      kind = kind or ""
      local text = content_to_string(content)

      if vim.g.juu_msg_redirect_suppress then
        return false
      end

      if not should_redirect(cfg, kind, text, trigger, exclude) then
        return false
      end

      local function dispatch()
        local ms = cfg.dedupe_ms
        local action = dedupe_action(text, ms)
        if action == "skip" then
          return
        end
        local use_chain = action == "supersede" or (action == "new" and likely_write_prefix(text))
        notify_message(kind, text, replace_last, id, cfg, use_chain)
      end

      if vim.in_fast_event() then
        vim.schedule(dispatch)
      else
        dispatch()
      end
      return true
    end

    -- Mode, ruler, showcmd, history, clear: leave to the default UI / other handlers.
    return false
  end)
end

---@param user? table
function M.setup(user)
  if M._initialized then
    return
  end

  if another_ui_handles_messages() then
    vim.notify_once("juu.nvim: message redirect is disabled because noice.nvim is loaded", vim.log.levels.WARN)
    return
  end

  if vim.fn.has("nvim-0.10") == 0 then
    return
  end

  local cfg = config.messages
  if cfg == false or (type(cfg) == "table" and cfg.enabled == false) then
    return
  end

  if config.notify == false then
    vim.notify_once("juu.nvim: enable notifications (notify ~= false) to use message redirect", vim.log.levels.WARN)
    return
  end

  local merged = vim.tbl_deep_extend("force", type(cfg) == "table" and cfg or {}, user or {})

  local ok, err = pcall(attach, merged)
  if not ok then
    vim.notify("juu.nvim: could not attach message handler: " .. tostring(err), vim.log.levels.WARN)
    return
  end

  M._initialized = true
end

function M.detach()
  if M._ns then
    pcall(vim.ui_detach, M._ns)
    M._ns = nil
  end
  local ok, msg = pcall(require, "vim._core.ui2.messages")
  if ok and type(msg) == "table" and msg._juu_skip_redirect_orig then
    msg.msg_show = msg._juu_skip_redirect_orig
    msg._juu_skip_redirect_orig = nil
  end
  M._initialized = false
end

return M
