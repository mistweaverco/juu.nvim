local config = require("juu.config")
local patch = require("juu.patch")

local M = {}

local function cmdline_enabled()
  local c = config.cmdline
  return c ~= false and (type(c) ~= "table" or c.enabled ~= false)
end

local function messages_wanted()
  local m = config.messages
  return m ~= false and (type(m) ~= "table" or m.enabled ~= false)
end

-- The "report_" functions have been deprecated, so use the new ones if defined.
---@diagnostic disable: deprecated
local health_start = vim.health.start or vim.health.report_start
local health_warn = vim.health.warn or vim.health.report_warn
local health_ok = vim.health.ok or vim.health.report_ok

M.check = function()
  health_start("juu.nvim")
  if patch.is_enabled("input") then
    health_ok("vim.ui.input active")
  else
    health_warn("vim.ui.input not enabled")
  end

  if patch.is_enabled("select") then
    local _, name = require("juu.select").get_backend(config.select.backend)
    health_ok("vim.ui.select active: " .. name)
  else
    health_warn("vim.ui.select not enabled")
  end

  if not cmdline_enabled() then
    health_ok("floating cmdline disabled (juu.config.cmdline)")
  elseif vim.fn.has("nvim-0.12") == 0 then
    health_warn("floating cmdline requires Neovim >= 0.12 (ui2)")
  elseif require("juu.cmdline")._initialized then
    health_ok("floating cmdline active (Neovim ui2)")
  else
    health_warn("floating cmdline did not initialize (see :messages)")
  end

  if config.notify == false then
    health_ok("message redirect inactive (notifications disabled)")
  elseif not messages_wanted() then
    health_ok("message redirect disabled (juu.config.messages)")
  elseif package.loaded["noice"] then
    health_ok("message redirect skipped (noice.nvim handles ui-messages)")
  elseif require("juu.messages")._initialized then
    health_ok("message redirect active (msg_show → juu.notify)")
  else
    health_warn("message redirect did not initialize (see :messages)")
  end
end

return M
