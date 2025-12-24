function! juu#fzf_run(labels, options, window) abort
	call fzf#run(fzf#wrap({
        \ 'source': a:labels,
        \ 'sink': funcref('juu#fzf_choice'),
        \ 'options': a:options,
        \ 'window': a:window,
        \}))
endfunction

function! juu#fzf_choice(label) abort
	call v:lua.juu_fzf_choice(a:label)
endfunction
