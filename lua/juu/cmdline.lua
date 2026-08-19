--- Floating cmdline positioning (Neovim 0.12+ ui2),
--- inspired by tiny-cmdline.nvim.
--- https://github.com/rachartier/tiny-cmdline.nvim
local config = require("juu.config")

local M = {}

M._initialized = false

---@class JuuCmdlineAdapters
M.adapters = {
  ---@type fun(): nil
  blink = function()
    local ok, menu = pcall(require, "blink.cmp.completion.windows.menu")
    if ok and menu.win and menu.win:is_open() then
      pcall(menu.update_position)
    end
  end,
}

---@type JuuCmdlineConfig
M.config = {}

-- "60%" -> fraction of available; integer -> absolute
local function parse_dimension(value, available)
  if type(value) == "string" then
    return math.floor(available * tonumber(value:match("^(%d+)%%$")) / 100)
  end
  return math.floor(value)
end

---@param content_height integer
---@return integer width, integer row, integer col, integer b
local function geometry(content_height)
  local cols, lines = vim.o.columns, vim.o.lines
  local b = M.config.border == "none" and 0 or 1
  local width = math.max(M.config.width.min, math.min(M.config.width.max, parse_dimension(M.config.width.value, cols)))
  width = math.min(width, cols - 4)

  local row = math.max(0, parse_dimension(M.config.position.y, lines - content_height - b * 2))
  local col = math.max(0, parse_dimension(M.config.position.x, cols - width - b * 2))
  return width, row, col, b
end

local cmdline_type = nil ---@type string|nil
local cmdline_generation = 0
local original_ui_cmdline_pos = nil ---@type table|nil
local ui2 = nil ---@type table|nil
local cmdtype_override = nil ---@type string|nil
local get_cmd_win_override = nil ---@type (fun(): integer|nil)|nil

local wrapped = false
local cmdline_mod = nil ---@type table|nil
local cmdline_show_orig = nil ---@type function|nil
local schedule_if_current

local function getcmdtype()
  if cmdtype_override ~= nil then
    return cmdtype_override
  end
  return vim.fn.getcmdtype()
end

local function is_cmdline_active()
  return cmdline_type ~= nil and getcmdtype() ~= ""
end

local function get_cmd_win()
  if get_cmd_win_override then
    return get_cmd_win_override()
  end
  if not ui2 then
    local ok, mod = pcall(require, "vim._core.ui2")
    if not ok then
      return nil
    end
    ui2 = mod
  end
  local win = ui2.wins and ui2.wins.cmd
  return (win and vim.api.nvim_win_is_valid(win)) and win or nil
end

local function on_cmdline_enter()
  cmdline_generation = cmdline_generation + 1
  cmdline_type = getcmdtype()
end

--- Return the UI2 command window to the presentation UI2 expects when idle.
--- UI2's cmdline_hide only toggles `hide` (when cmdheight is 0) or height; it
--- does not undo Juu's relative/border/size changes, so the float would
--- otherwise remain on screen after leaving the command line.
local function restore_ui2_presentation()
  if is_cmdline_active() then
    return
  end
  local win = get_cmd_win()
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  -- Only fields Juu itself changes while the command line is active.
  -- Do not set focusable, zindex, or height: those remain UI2's.
  pcall(vim.api.nvim_win_set_config, win, {
    relative = "laststatus",
    row = 1,
    col = 0,
    width = 10000,
    border = "none",
    hide = vim.o.cmdheight == 0,
  })
  pcall(function()
    vim.wo[win].winhighlight = "Normal:MsgArea,Search:,CurSearch:,IncSearch:"
  end)
end

local function on_cmdline_leave()
  -- UI2 owns the command-line window. Once CmdlineLeave fires, Juu must stop
  -- manipulating that window synchronously. UI2 may still have scheduled
  -- cmdline-hide/redraw work pending, and touching the window during that
  -- transition can interfere with focusable windows opened by the command
  -- that just completed.
  cmdline_type = nil
  vim.g.ui_cmdline_pos = original_ui_cmdline_pos
  -- Restore presentation on the next tick so a just-opened modal keeps focus.
  schedule_if_current(restore_ui2_presentation)
end

local function reposition()
  if not is_cmdline_active() then
    return
  end
  local win = get_cmd_win()
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  pcall(function()
    vim.wo[win].winhighlight = "Normal:JuuCmdlineNormal,FloatBorder:JuuCmdlineBorder"
  end)

  local content_height = math.max(1, vim.api.nvim_win_get_height(win))

  if vim.tbl_contains(M.config.native_types, cmdline_type) then
    pcall(vim.api.nvim_win_set_config, win, {
      relative = "editor",
      row = math.max(0, vim.o.lines - content_height),
      col = 0,
      width = vim.o.columns,
      border = "none",
    })
    vim.g.ui_cmdline_pos = original_ui_cmdline_pos
    return
  end

  local width, row, col, b = geometry(content_height)
  pcall(vim.api.nvim_win_set_config, win, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    border = M.config.border,
  })
  -- Anchor for blink.cmp / nvim-cmp completion menu
  vim.g.ui_cmdline_pos = { row + content_height + b * 2, col + b + M.config.menu_col_offset }

  if M.config.on_reposition then
    M.config.on_reposition()
  end
end

--- Schedule UI work that must only run if this command-line session is still current.
---@param fn fun()
function schedule_if_current(fn)
  local generation = cmdline_generation
  vim.schedule(function()
    -- Scheduled UI work from an earlier command-line session must never modify
    -- the state of a newer session.
    if generation ~= cmdline_generation then
      return
    end
    fn()
  end)
end

local function unwrap_cmdline_show()
  if wrapped and cmdline_mod and cmdline_show_orig then
    cmdline_mod.cmdline_show = cmdline_show_orig
  end
  wrapped = false
  cmdline_mod = nil
  cmdline_show_orig = nil
end

local function wrap_cmdline_show()
  if wrapped then
    return
  end
  local ok, cmdline = pcall(require, "vim._core.ui2.cmdline")
  if not ok then
    return
  end
  cmdline_mod = cmdline
  cmdline_show_orig = cmdline.cmdline_show
  cmdline.cmdline_show = function(...)
    local result = cmdline_show_orig(...)

    local current_type = getcmdtype()
    if current_type == "" then
      return result
    end

    cmdline_type = current_type
    reposition()

    return result
  end
  wrapped = true
end

---@param opts JuuCmdlineConfig|nil
function M.setup(opts)
  if M._initialized then
    return
  end

  local cfg = config.cmdline
  if cfg == false or (type(cfg) == "table" and cfg.enabled == false) then
    return
  end

  if vim.fn.has("nvim-0.12") == 0 and not vim.g.juu_test then
    vim.notify("juu.nvim cmdline styling requires Neovim >= 0.12", vim.log.levels.WARN)
    return
  end

  M._initialized = true

  vim.api.nvim_set_hl(0, "JuuCmdlineNormal", { link = "MsgArea", default = true })
  vim.api.nvim_set_hl(0, "JuuCmdlineBorder", { link = "FloatBorder", default = true })

  M.config = vim.tbl_deep_extend("force", vim.deepcopy(type(cfg) == "table" and cfg or {}), opts or {})

  original_ui_cmdline_pos = vim.g.ui_cmdline_pos
  if M.config.border == nil then
    local wb = vim.o.winborder
    M.config.border = wb ~= "" and wb or "rounded"
  end

  local group = vim.api.nvim_create_augroup("juu-cmdline", { clear = true })

  vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = group,
    callback = on_cmdline_enter,
  })

  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = on_cmdline_leave,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "cmd",
    callback = function()
      schedule_if_current(function()
        wrap_cmdline_show()
        reposition()
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ "VimResized", "TabEnter" }, {
    group = group,
    callback = function()
      schedule_if_current(reposition)
    end,
  })

  schedule_if_current(function()
    wrap_cmdline_show()
    reposition()
  end)
end

if vim.g.juu_test then
  --- Private test surface. Not a public API.
  M._test = {
    is_cmdline_active = is_cmdline_active,
    on_cmdline_enter = on_cmdline_enter,
    on_cmdline_leave = on_cmdline_leave,
    reposition = reposition,
    wrap_cmdline_show = wrap_cmdline_show,
    restore_ui2_presentation = restore_ui2_presentation,
    schedule_if_current = schedule_if_current,
    generation = function()
      return cmdline_generation
    end,
    type = function()
      return cmdline_type
    end,
    set_cmdtype = function(value)
      cmdtype_override = value
    end,
    set_get_cmd_win = function(fn)
      get_cmd_win_override = fn
    end,
    reset = function()
      cmdline_type = nil
      cmdline_generation = 0
      ui2 = nil
      cmdtype_override = nil
      get_cmd_win_override = nil
      unwrap_cmdline_show()
      vim.g.ui_cmdline_pos = original_ui_cmdline_pos
    end,
  }
end

return M
