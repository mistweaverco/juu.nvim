local M = {}

local namespace = vim.api.nvim_create_namespace("juu.notify")

function M.namespace()
  return namespace
end

return M
