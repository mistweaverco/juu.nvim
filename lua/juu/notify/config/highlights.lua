local M = {}

function M.setup()
  vim.cmd([[
    hi default link JuuNotifyBackground Normal
    hi default JuuNotifyERRORBorder guifg=#8A1F1F
    hi default JuuNotifyWARNBorder guifg=#79491D
    hi default JuuNotifyINFOBorder guifg=#4F6752
    hi default JuuNotifyDEBUGBorder guifg=#8B8B8B
    hi default JuuNotifyTRACEBorder guifg=#4F3552
    hi default JuuNotifyERRORIcon guifg=#F70067
    hi default JuuNotifyWARNIcon guifg=#F79000
    hi default JuuNotifyINFOIcon guifg=#A9FF68
    hi default JuuNotifyDEBUGIcon guifg=#8B8B8B
    hi default JuuNotifyTRACEIcon guifg=#D484FF
    hi default JuuNotifyERRORTitle  guifg=#F70067
    hi default JuuNotifyWARNTitle guifg=#F79000
    hi default JuuNotifyINFOTitle guifg=#A9FF68
    hi default JuuNotifyDEBUGTitle  guifg=#8B8B8B
    hi default JuuNotifyTRACETitle  guifg=#D484FF
    hi default link JuuNotifyERRORBody Normal
    hi default link JuuNotifyWARNBody Normal
    hi default link JuuNotifyINFOBody Normal
    hi default link JuuNotifyDEBUGBody Normal
    hi default link JuuNotifyTRACEBody Normal

    hi default link JuuNotifyLogTime Comment
    hi default link JuuNotifyLogTitle Special
  ]])
end

M.setup()

vim.cmd([[
  augroup NvimJuuNotifyRefreshHighlights
    autocmd!
    autocmd ColorScheme * lua require('juu.notify.config.highlights').setup()
  augroup END
]])

return M
