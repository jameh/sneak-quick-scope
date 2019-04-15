" function to wait to print error messages
function! sneak_quick_scope#lazy_print#err(message) abort
  augroup sneak_quick_scope_lazy_print
    autocmd!
    " clear the augroup so that these lazy loaded error messages only execute
    " once after starting
  augroup END
  echohl ErrorMsg
  echomsg 'sneak_quick_scope ' . a:message
  echohl None
endfunction
