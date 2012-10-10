" Edits part of buffer by another buffer.
" Version: 1.0
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

function! partedit#start(startline, endline, ...)
  if &l:readonly || !&l:modifiable
    echohl ErrorMsg
    echomsg 'The buffer is readonly or nomodifiable.'
    echohl None
    return
  endif
  let original_bufnr = bufnr('%')
  let contents = getline(a:startline, a:endline)
  let original_contents = contents
  let prefix = get(b:, 'partedit_prefix', '')
  if prefix !=# ''
    let sprefix = substitute(prefix, '\s\+$', '', '')
    let len = len(sprefix)
    let pos = len - 1
    let all_prefix_exists = 1
    for line in contents
      if line[: pos] !=# sprefix
        let all_prefix_exists = 0
        break
      endif
    endfor
    if all_prefix_exists
      let original_contents = copy(contents)
      let pat = '^' . substitute(prefix, '\s\+$', '\\%(\0\\|$\\)', '')
      call map(contents, 'substitute(v:val, pat, "", "")')
    else
      let prefix = ''
    endif
  endif

  let filetype = get(b:, 'partedit_filetype', &l:filetype)

  let partial_bufname = printf('%s#%d-%d', bufname(original_bufnr),
  \                            a:startline, a:endline)

  let opener = a:0 && a:1 =~# '\S' ? a:1 : 'edit'
  noautocmd hide execute opener '`=partial_bufname`'

  silent put =s:adjust(contents)
  silent 1 delete _

  let b:partedit__bufnr = original_bufnr
  let b:partedit__lines = [a:startline, a:endline]
  let b:partedit__contents = original_contents
  let b:partedit__prefix = prefix
  setlocal buftype=acwrite nomodified bufhidden=wipe noswapfile

  let &l:filetype = filetype

  augroup plugin-partedit
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> nested call s:apply()
  augroup END
endfunction

function! s:apply()
  let [start, end] = b:partedit__lines

  if !v:cmdbang &&
  \    b:partedit__contents != getbufline(b:partedit__bufnr, start, end)
    " TODO: Takes a proper step.
    let all = getbufline(b:partedit__bufnr, 1, '$')
    let line = s:search_partial(all, b:partedit__contents, start) + 1
    if line
      let [start, end] = [line, line + end - start]

    else
      echo 'The range in the original buffer was changed.  Overwrite? [yN]'
      if nr2char(getchar()) !~? 'y'
        return
      endif
    endif
  endif

  let contents = getline(1, '$')
  if b:partedit__prefix !=# ''
    let prefix = b:partedit__prefix
    let sprefix = substitute(prefix, '\s\+$', '', '')
    call map(contents, '(v:val ==# "" ? sprefix : prefix) . v:val')
  endif
  let bufnr = bufnr('%')

  setlocal bufhidden=hide
  noautocmd execute 'keepjumps' b:partedit__bufnr 'buffer'

  let modified = &l:modified

  silent execute printf('%d,%d delete _', start, end)
  silent execute start - 1 'put' '=s:adjust(contents)'

  if !modified
    write
  endif

  noautocmd execute 'keepjumps hide' bufnr 'buffer'
  setlocal bufhidden=wipe

  let b:partedit__contents = contents
  let b:partedit__lines = [start, start + len(contents) - 1]
  setlocal nomodified
endfunction

function! s:adjust(lines)
  return a:lines[-1] == '' ? a:lines + [''] : a:lines
endfunction

function! s:search_partial(all, part, base)
  let l = len(a:part)
  let last = len(a:all)
  let s:base = a:base
  for n in sort(range(last), 's:sort')
    if n + l <= last && a:all[n] == a:part[0] &&
  \      a:all[n : n + l - 1] == a:part
      return n
    end
  endfor
  return -1
endfunction


function! s:sort(a, b)
  return abs(a:a - s:base) - abs(a:b - s:base)
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
