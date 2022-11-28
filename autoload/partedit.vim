" Edits part of buffer by another buffer.
" Version: 1.2
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

function! partedit#command(startline, endline, args)
  let options = {}
  let rest = a:args
  while rest =~# '^\s*-\w\+'
    let [opt, rest] = matchlist(rest, '^\s*-\(\w\+\)\s*\(.*\)')[1 : 2]
    if rest[0] =~# '["'']'
      let q = rest[0]
      let rest = rest[1 :]
      let pos = match(rest, '\\\@<!' . q)
      if 0 <= pos
        let value = substitute(rest[: pos - 1], '\\\(.\)', '\1', 'g')
        let rest = rest[pos + 1 :]
      else
        let value = rest
        let rest = ''
      endif
    else
      let [value, rest] = matchlist(rest, '^\(\S\+\)\s*\(.*\)')[1 : 2]
    endif
    let options[opt] = value
  endwhile
  if rest =~# '\S'
    let options.opener = rest
  endif
  call partedit#start(a:startline, a:endline, options)
endfunction

function! partedit#complete(lead, cmd, pos)
  let options = ['-opener', '-prefix', '-filetype', '-auto_prefix']
  return filter(options, 'v:val =~# "^\\V" . escape(a:lead, "\\")')
endfunction

function! partedit#start(startline, endline, ...)
  if &l:readonly || !&l:modifiable
    echohl ErrorMsg
    echomsg 'The buffer is readonly or nomodifiable.'
    echohl None
    return
  endif
  let options = a:0 ? a:1 : {}
  let original_bufnr = bufnr('%')
  let contents = getline(a:startline, a:endline)
  let original_contents = copy(contents)

  let prefix = s:get_option('prefix', options, '')
  let auto_prefix = s:get_option('auto_prefix', options, 1)
  let prefix_pattern = s:get_option('prefix_pattern', options, '')
  let [contents, prefix] = s:trim_contents(contents, prefix, auto_prefix, prefix_pattern)

  let filetype = s:get_option('filetype', options, &l:filetype)
  let [fenc, ff] = [&l:fileencoding, &l:fileformat]

  let partial_bufname = printf('%s#%d-%d', bufname(original_bufnr),
  \                            a:startline, a:endline)

  let opener = s:get_option('opener', options, 'edit')
  if opener[0] ==# '='
    let opener = eval(opener[1 :])
  endif
  let bufhidden = &l:bufhidden
  setlocal bufhidden=hide
  noautocmd hide execute opener '`=partial_bufname`'

  let [&l:fileencoding, &l:fileformat] = [fenc, ff]
  silent % delete _
  call setline(1, contents)

  let b:partedit__bufnr = original_bufnr
  let b:partedit__lines = [a:startline, a:endline]
  let b:partedit__contents = original_contents
  let b:partedit__prefix = prefix
  let b:partedit__bufhidden = bufhidden
  setlocal buftype=acwrite nomodified bufhidden=wipe noswapfile

  command! -buffer -bar ParteditEnd execute b:partedit__bufnr 'buffer'

  let &l:filetype = filetype

  augroup plugin-partedit
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> nested call s:apply()
    autocmd BufWipeout  <buffer> nested
    \   call setbufvar(b:partedit__bufnr, '&bufhidden', b:partedit__bufhidden)
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
  silent execute start - 1 'put' '=contents'

  if &l:buftype =~# '^\%(\|acwrite\)$' && !modified
    write
  endif

  noautocmd execute 'keepjumps hide' bufnr 'buffer'
  setlocal bufhidden=wipe

  let b:partedit__contents = contents
  let b:partedit__lines = [start, start + len(contents) - 1]
  setlocal nomodified
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

function! s:get_option(name, base, default)
  if has_key(a:base, a:name)
    return a:base[a:name]
  endif
  if exists('b:partedit_' . a:name)
    return b:partedit_{a:name}
  endif
  if exists('g:partedit#' . a:name)
    return g:partedit#{a:name}
  endif
  return a:default
endfunction

function! s:trim_contents(contents, prefix, auto_prefix, prefix_pattern,)
  let contents = a:contents
  let prefix = a:prefix

  if a:prefix_pattern !=# ''

    let allow_empty_line = ('' =~# '^' .. a:prefix_pattern)

    let len_prefix = -1
    for line in contents
      if line ==# ''
        if allow_empty_line
          continue
        else
          let prefix = ''
          let len_prefix = 0
          break
        endif
      endif
      if len_prefix > 0
        let line = line[:len_prefix - 1]
      endif
      let prefix_provisional = matchstr(line, '^' .. a:prefix_pattern)
      let len_prefix = strlen(prefix_provisional)
      if len_prefix == 0
        break
      endif
    endfor

    call map(contents, 'v:val[len_prefix:]')
    let prefix = prefix_provisional

  else

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
        let pat = '^' . substitute(prefix, '\s\+$', '\\%(\0\\|$\\)', '')
        call map(contents, 'substitute(v:val, pat, "", "")')
      else
        let prefix = ''
      endif
    endif
    if prefix ==# '' && a:auto_prefix && 2 <= len(contents)
      let prefix = contents[0]
      for line in contents[1 :]
        if line ==# ''
          continue
        endif
        let pat = escape(substitute(line, '.', '[\0]', 'g'),'\')
        let prefix = matchstr(prefix, '^\%[' . pat . ']')
        if prefix ==# ''
          break
        endif
      endfor
      if prefix !=# ''
        let len = len(prefix)
        call map(contents, 'v:val[len :]')
      endif
    endif

  endif

  return [contents, prefix]
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
