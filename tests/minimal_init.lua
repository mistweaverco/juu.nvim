vim.g.juu_test = true
vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h"))
vim.cmd("filetype plugin indent on")
