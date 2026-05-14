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
local original_ui_cmdline_pos = nil ---@type table|nil
local cmd_win_saved = nil ---@type table|nil
local ui2 = nil ---@type table|nil

local function get_cmd_win()
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

local function reposition()
  if not cmdline_type then
    return
  end
  local win = get_cmd_win()
  if not win then
    return
  end

  -- saved once and restored on CmdlineLeave so post-command messages render at the bottom
  if not cmd_win_saved then
    local cfg = vim.api.nvim_win_get_config(win)
    cmd_win_saved = {
      relative = cfg.relative,
      anchor = cfg.anchor,
      col = cfg.col,
      row = cfg.row,
      width = cfg.width,
      border = cfg.border,
    }
    vim.wo[win].winhighlight = "Normal:JuuCmdlineNormal,FloatBorder:JuuCmdlineBorder"
  end

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

local wrapped = false
local function wrap_cmdline_show()
  if wrapped then
    return
  end
  local ok, cmdline = pcall(require, "vim._core.ui2.cmdline")
  if not ok then
    return
  end
  local orig = cmdline.cmdline_show
  cmdline.cmdline_show = function(...)
    local r = orig(...)
    if not cmdline_type then
      return r
    end

    reposition()
    return r
  end
  wrapped = true
end

local function wrap_and_reposition()
  wrap_cmdline_show()
  reposition()
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

  if vim.fn.has("nvim-0.12") == 0 then
    vim.notify("juu.nvim cmdline styling requires Neovim >= 0.12", vim.log.levels.WARN)
    return
  end

  M._initialized = true

  vim.api.nvim_set_hl(0, "JuuCmdlineNormal", { link = "MsgArea", default = true })
  vim.api.nvim_set_hl(0, "JuuCmdlineBorder", { link = "FloatBorder", default = true })

  M.config = vim.tbl_deep_extend("force", vim.deepcopy(type(cfg) == "table" and cfg or {}), opts or {})

  original_ui_cmdline_pos = vim.g.ui_cmdline_pos
  cmd_win_saved = nil
  if M.config.border == nil then
    local wb = vim.o.winborder
    M.config.border = wb ~= "" and wb or "rounded"
  end

  local group = vim.api.nvim_create_augroup("juu-cmdline", { clear = true })

  vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = group,
    callback = function()
      cmdline_type = vim.fn.getcmdtype()
    end,
  })

  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      local was_native = vim.tbl_contains(M.config.native_types, cmdline_type)
      cmdline_type = nil
      vim.g.ui_cmdline_pos = original_ui_cmdline_pos

      -- restore original position without hiding so ui2 can display post-command messages
      local win = get_cmd_win()
      if win and cmd_win_saved then
        pcall(vim.api.nvim_win_set_config, win, cmd_win_saved)
      end
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "cmd",
    callback = function()
      vim.schedule(wrap_and_reposition)
    end,
  })

  vim.api.nvim_create_autocmd({ "VimResized", "TabEnter" }, {
    group = group,
    callback = function()
      vim.schedule(reposition)
    end,
  })

  vim.schedule(wrap_and_reposition)
end

return M
