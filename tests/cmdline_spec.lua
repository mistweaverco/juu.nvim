-- luacheck: ignore 122
local cmdline = require("juu.cmdline")
cmdline.setup()

local T = cmdline._test
assert(T, "juu.cmdline test surface missing (set vim.g.juu_test before requiring)")

local passed = 0
local failed = 0
local failures = {}
local orig_set_config = vim.api.nvim_win_set_config
local root_win = vim.api.nvim_get_current_win()

local function flush()
  local done = false
  vim.schedule(function()
    vim.schedule(function()
      done = true
    end)
  end)
  vim.wait(1000, function()
    return done
  end)
end

flush()

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", msg or "assert_eq", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function assert_true(cond, msg)
  if not cond then
    error(msg or "expected condition to be true", 2)
  end
end

local function cleanup_floats()
  vim.api.nvim_win_set_config = orig_set_config
  if vim.api.nvim_win_is_valid(root_win) then
    pcall(vim.api.nvim_set_current_win, root_win)
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= root_win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

local function test(name, fn)
  T.reset()
  cleanup_floats()
  cmdline.config = vim.tbl_deep_extend("force", cmdline.config, {
    native_types = {},
    border = "rounded",
    width = { value = "60%", min = 40, max = 80 },
    position = { x = "50%", y = "50%" },
    menu_col_offset = 3,
  })
  local ok, err = pcall(fn)
  cleanup_floats()
  if ok then
    passed = passed + 1
    print("  ok  " .. name)
  else
    failed = failed + 1
    table.insert(failures, name .. ": " .. tostring(err))
    print("  FAIL  " .. name)
  end
end

local function make_float(enter)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, enter == true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 20,
    height = 1,
    style = "minimal",
  })
  return buf, win
end

local function spy_set_config()
  local calls = { n = 0 }
  local orig = vim.api.nvim_win_set_config
  vim.api.nvim_win_set_config = function(...)
    calls.n = calls.n + 1
    return orig(...)
  end
  calls.restore = function()
    vim.api.nvim_win_set_config = orig
  end
  return calls
end

test("CmdlineEnter updates generation", function()
  assert_eq(T.generation(), 0, "initial generation")
  T.set_cmdtype(":")
  vim.api.nvim_exec_autocmds("CmdlineEnter", { group = "juu-cmdline" })
  assert_eq(T.generation(), 1, "generation after enter")
  assert_eq(T.type(), ":", "cmdline_type after enter")
end)

test("CmdlineLeave immediately disables repositioning", function()
  local _, win = make_float(false)
  T.set_get_cmd_win(function()
    return win
  end)
  T.set_cmdtype(":")
  T.on_cmdline_enter()

  local spy = spy_set_config()
  T.set_cmdtype("")
  T.on_cmdline_leave()
  T.reposition()
  spy.restore()

  assert_eq(spy.n, 0, "no synchronous window mutation after leave")
  assert_true(not T.is_cmdline_active(), "cmdline should be inactive")
end)

test("deferred restore after leave returns UI2 presentation", function()
  local _, win = make_float(false)
  T.set_get_cmd_win(function()
    return win
  end)
  T.set_cmdtype(":")
  T.on_cmdline_enter()
  T.set_cmdtype("")
  T.on_cmdline_leave()

  local spy = spy_set_config()
  flush()
  spy.restore()

  assert_true(spy.n > 0, "idle presentation should be restored after leave")
  local cfg = vim.api.nvim_win_get_config(win)
  assert_eq(cfg.relative, "laststatus", "relative restored")
  assert_eq(cfg.border, "none", "border restored")
end)

test("stale scheduled callbacks are ignored", function()
  local _, win = make_float(false)
  T.set_get_cmd_win(function()
    return win
  end)

  T.set_cmdtype(":")
  T.on_cmdline_enter()
  T.set_cmdtype("")
  T.on_cmdline_leave()

  local spy = spy_set_config()
  T.schedule_if_current(T.reposition)

  T.set_cmdtype(":")
  T.on_cmdline_enter()
  flush()
  spy.restore()

  assert_eq(T.generation(), 2, "second session generation")
  assert_eq(spy.n, 0, "session 1 callback must not mutate")
end)

test("active cmdline_show still repositions", function()
  local orig_called = false
  local orig_args
  package.loaded["vim._core.ui2.cmdline"] = {
    cmdline_show = function(...)
      orig_called = true
      orig_args = { ... }
      return "shown"
    end,
  }
  T.wrap_cmdline_show()

  local _, win = make_float(false)
  T.set_get_cmd_win(function()
    return win
  end)
  T.set_cmdtype(":")

  local spy = spy_set_config()
  local result = package.loaded["vim._core.ui2.cmdline"].cmdline_show("content", 1)
  spy.restore()

  assert_true(orig_called, "original cmdline_show must be called")
  assert_eq(orig_args[1], "content", "original arguments")
  assert_eq(result, "shown", "original return value")
  assert_eq(T.type(), ":", "synchronized cmdline_type")
  assert_true(spy.n > 0, "reposition should mutate the cmd window")
end)

test("inactive cmdline_show does not reposition", function()
  local orig_called = false
  package.loaded["vim._core.ui2.cmdline"] = {
    cmdline_show = function()
      orig_called = true
      return "hidden"
    end,
  }
  T.wrap_cmdline_show()

  local _, win = make_float(false)
  T.set_get_cmd_win(function()
    return win
  end)
  T.set_cmdtype("")

  local spy = spy_set_config()
  local result = package.loaded["vim._core.ui2.cmdline"].cmdline_show()
  spy.restore()

  assert_true(orig_called, "original cmdline_show must be called")
  assert_eq(result, "hidden", "original return value")
  assert_eq(spy.n, 0, "inactive cmdline_show must not reposition")
end)

test("nil UI2 window is harmless", function()
  T.set_cmdtype(":")
  T.on_cmdline_enter()
  T.set_get_cmd_win(function()
    return nil
  end)
  local current = vim.api.nvim_get_current_win()
  T.reposition()
  assert_eq(vim.api.nvim_get_current_win(), current, "focus unchanged")
end)

test("invalid UI2 window is harmless", function()
  T.set_cmdtype(":")
  T.on_cmdline_enter()
  T.set_get_cmd_win(function()
    return 999999
  end)
  local current = vim.api.nvim_get_current_win()
  T.reposition()
  assert_eq(vim.api.nvim_get_current_win(), current, "focus unchanged")
end)

test("focusable modal keeps focus after CmdlineLeave", function()
  T.set_cmdtype(":")
  vim.api.nvim_exec_autocmds("CmdlineEnter", { group = "juu-cmdline" })

  local buf = vim.api.nvim_create_buf(false, true)
  local win
  vim.schedule(function()
    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      row = 5,
      col = 5,
      width = 40,
      height = 5,
      style = "minimal",
      border = "rounded",
    })
  end)

  T.set_cmdtype("")
  vim.api.nvim_exec_autocmds("CmdlineLeave", { group = "juu-cmdline" })
  T.schedule_if_current(T.reposition)
  flush()

  assert_true(win ~= nil, "modal window was created")
  assert_eq(vim.api.nvim_get_current_win(), win, "modal must remain current")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
  for _, f in ipairs(failures) do
    print("FAIL: " .. f)
  end
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
