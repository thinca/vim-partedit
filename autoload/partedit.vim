" Edit a part of a buffer with a another buffer.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



function! partedit#start(startline, endline, splitcmd)
  let original_bufnr = bufnr('%')
  let contents = getline(a:startline, a:endline)
  let filetype = &l:filetype

  let partial_bufname = printf('%s#%d-%d', bufname(original_bufnr),
  \                            a:startline, a:endline)

  execute a:splitcmd
  noautocmd hide edit `=partial_bufname`

  silent put =contents
  silent 1 delete _

  let b:partedit_bufnr = original_bufnr
  let b:partedit_lines = [a:startline, a:endline]
  let b:partedit_contents = contents
  setlocal buftype=acwrite nomodified bufhidden=wipe

  let &l:filetype = filetype

  augroup plugin-partedit
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> nested call s:apply()
  augroup END
endfunction



function! s:apply()
  let [start, end] = b:partedit_lines

  if b:partedit_contents != getbufline(b:partedit_bufnr, start, end)
    " TODO: Takes a proper step.
    echo 'The range in the original buffer was changed.  Overwrite? [yN]'
    if getchar() !~? 'y'
      return
    endif
  endif

  let contents = getline(1, '$')
  let bufnr = bufnr('%')

  setlocal bufhidden=hide
  noautocmd execute 'keepjumps' b:partedit_bufnr 'buffer'

  silent execute printf('%d,%d delete _', start, end)
  silent execute start 'put!' '=contents'

  noautocmd execute 'keepjumps hide' bufnr 'buffer'
  setlocal bufhidden=wipe

  let b:partedit_contents = contents
  let b:partedit_lines = [start, start + len(contents) - 1]
  setlocal nomodified
endfunction



let &cpo = s:save_cpo
unlet s:save_cpo
