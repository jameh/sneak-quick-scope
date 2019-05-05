" Initialize -----------------------------------------------------------------
let s:plugin_name = 'sneak-quick-scope'

if exists('g:loaded_sneak_quick_scope')
  finish
endif

let g:loaded_sneak_quick_scope = 1

if &compatible
  echoerr s:plugin_name . " won't load in Vi-compatible mode."
  finish
endif

if v:version < 701 || (v:version == 701 && !has('patch040'))
  echoerr s:plugin_name . ' requires Vim running in version 7.1.040 or later.'
  finish
endif

" Save cpoptions and reassign them later. See :h use-cpo-save.
let s:cpo_save = &cpo
set cpo&vim

" Autocommands ---------------------------------------------------------------
augroup sneak_quick_scope
  autocmd!
  autocmd ColorScheme * call s:set_highlight_colors()
augroup END

" Options --------------------------------------------------------------------
if !exists('g:sqs_enable')
  let g:sqs_enable = 0
endif

"TODO hardcoded for now
" if !exists('g:sqs_highlight_current_line')
"   let g:sqs_highlight_current_line = 0
" endif

let g:sqs_last_time = reltime()

if !exists('g:sqs_minimum_time')
  let g:sqs_minimum_time = 0.0
endif

if !exists('g:sqs_lazy_highlight')
  let g:sqs_lazy_highlight = 1
endif

if !exists('g:sqs_blacklisted_filetypes')
  let g:sqs_blacklisted_filetypes = ['startify', 'gitcommit', 'help', '',
        \ 'calendar', 'gitmessengerpopup']
endif

"TODO hardcoded for now
" if !exists('g:sqs_within_chars')
"   " Disable outside this many chars from the cursor
"   let g:sqs_within_chars = 1000
" endif

" if !exists('g:sqs_within_lines')
"   " Disable outside this many lines from the cursor
"   let g:sqs_within_lines = 100
" endif

"TODO hardcoded for now
" if !exists('g:sqs_accepted_chars')
"   let g:sqs_accepted_chars = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
"         \ 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x',
"         \ 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
"         \ 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 
"         \ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
" endif

augroup sneak_quick_scope
  if g:sqs_lazy_highlight
    autocmd CursorHold,InsertLeave,ColorScheme,WinEnter,BufEnter,FocusGained
          \ * call sneak_quick_scope#UnhighlightView() | 
          \ call sneak_quick_scope#HighlightView()
  else
    autocmd CursorHold,CursorMoved,InsertLeave,ColorScheme,WinEnter,BufEnter,FocusGained
          \ * call sneak_quick_scope#UnhighlightView() | 
          \ call sneak_quick_scope#HighlightView()
  endif
  autocmd InsertEnter,BufLeave,TabLeave,WinLeave,FocusLost
        \ * call sneak_quick_scope#UnhighlightView()
augroup END

" User commands --------------------------------------------------------------
command! -nargs=0 SneakQuickScopeToggle call sneak_quick_scope#Toggle()

" Plug mappings --------------------------------------------------------------
nnoremap <silent> <plug>(SneakQuickScopeToggle) 
      \ <Cmd>call sneak_quick_scope#Toggle()<cr>
xnoremap <silent> <plug>(SneakQuickScopeToggle) 
      \ <Cmd>call sneak_quick_scope#Toggle()<cr>

" Colors ---------------------------------------------------------------------
" Set the colors used for highlighting.
function! s:set_highlight_colors()
  " Priority for overruling other highlight matches.
  let g:sqs_hi_priority = 1

  " Highlight group marking first appearance of characters in a line.
  let g:sqs_hi_group_primary = 'SneakQuickScopePrimary'
  " Highlight group marking second appearance of characters in a line.
  let g:sqs_hi_group_secondary = 'SneakQuickScopeSecondary'
  " Highlight group marking dummy cursor when sneak-quick-scope is enabled on
  " key press.
  let g:sqs_hi_group_cursor = 'SneakQuickScopeCursor'

  execute 'highlight default link ' . g:sqs_hi_group_cursor . ' Cursor'
  execute 'highlight default link ' . g:sqs_hi_group_primary . ' Function'
  execute 'highlight default link ' . g:sqs_hi_group_secondary . ' Define'
endfunction

call s:set_highlight_colors()

let &cpo = s:cpo_save
unlet s:cpo_save
