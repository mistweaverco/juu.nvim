-- Test script to demonstrate different notification types.
-- Usage: :lua require("juu.demos.notify.types").show()

local NotifierModule = require("juu.notify")

local M = {}

function M.show(title)
  title = title or "Demo"
  require("juu").setup({ notify = { filter = vim.log.levels.DEBUG } })
  NotifierModule.notify("What a pretty info message", vim.log.levels.INFO, { title = title })
  NotifierModule.notify("What a pretty warning message", vim.log.levels.WARN, { title = title })
  NotifierModule.notify("What a pretty debug message", vim.log.levels.DEBUG, { title = title })
  NotifierModule.notify("What a pretty error message", vim.log.levels.ERROR, { title = title })
end

return M
