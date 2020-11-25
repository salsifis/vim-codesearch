" Vim source indexation plugin.
" Plugin author: Benoit Mortgat
" Main git repository: http://github.com/salsifis/vim-codesearchindex

if exists('s:codesearchindex_plugin_loaded')
  finish
endif
let s:codesearchindex_plugin_loaded = 1

" Expected arguments:
" 1. Index directory
" 2. Sources directory
" 3. Manifest command
" 4. Cindex directory
command -nargs=+ -bar DeclareIndex
      \ call codesearchindex#declareindex(<f-args>)

command -nargs=0 -bar MkIndex
      \ call codesearchindex#makefilelistandindex()

command -nargs=0 -bar UpdIndex
      \ call codesearchindex#updateindex()

command -nargs=+ -bang SearchExprInIndex
      \ call codesearchindex#searchindex('<bang>', 0, <q-args>)

command -nargs=1 -bang SearchWordInIndex
      \ call codesearchindex#searchindex('<bang>', 1, <q-args>)

command -register -bang SearchFromRegisterInIndex
      \ call codesearchindex#searchfromregister('<bang>', '<register>')

command -register StopIndex
      \ call codesearchindex#stop()

" vim: ts=2 sw=2 et tw=80 colorcolumn=+1
