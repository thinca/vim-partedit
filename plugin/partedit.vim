" Edits part of buffer by another buffer.
" Version: 1.0
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

if exists('g:loaded_partedit')
  finish
endif
let g:loaded_partedit = 1

let s:save_cpo = &cpo
set cpo&vim

command! -nargs=? -bar -range -complete=command Partedit
\        call partedit#command(<line1>, <line2>, <q-args>)

let &cpo = s:save_cpo
unlet s:save_cpo
