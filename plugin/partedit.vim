" Edit a part of a buffer with a another buffer.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

if exists('g:loaded_partedit')
  finish
endif
let g:loaded_partedit = 1

let s:save_cpo = &cpo
set cpo&vim

command! -nargs=? -bar -range Partedit call partedit#start(<line1>, <line2>, <q-args>)

let &cpo = s:save_cpo
unlet s:save_cpo
