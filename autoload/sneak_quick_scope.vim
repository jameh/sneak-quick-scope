" Autoload interface functions -------------------------------------------------

function! sneak_quick_scope#Toggle() abort
  if g:sqs_enable
    let g:sqs_enable = 0
    call sneak_quick_scope#UnhighlightView()
  else
    let g:sqs_enable = 1
    doautocmd CursorMoved
  endif
endfunction

function! sneak_quick_scope#HighlightView() abort
  if g:sqs_enable && reltimefloat(reltime(g:sqs_last_time)) > g:sqs_minimum_time
        \ && index(g:sqs_blacklisted_filetypes, &filetype) == -1
    let g:sqs_last_time = reltime()
    let topline = line("w0")
    let botline = line("w$")
    let line_num = line(".") - topline
    let col_num = col('.')
    let i = topline
    let lines = []
    while i <= botline
      call add(lines, getline(i))
      let i += 1
    endwhile

    let text = join(lines, "\n")
    let cmd = "sneak_quick_scope " .
          \ shellescape(line_num) . " " . shellescape(col_num) . " " .
          \ shellescape(topline) . " " .
          \ shellescape("")  . " " . shellescape(text)
    let patterns = systemlist(cmd)

    if !v:shell_error
      if len(patterns) == 2
        call sneak_quick_scope#apply_highlight_patterns(patterns)
      endif
    else
      echoerr "Highlight failed"
    endif
  endif
endfunction

function! sneak_quick_scope#UnhighlightView() abort
  for m in filter(getmatches(), 
        \ printf('v:val.group ==# "%s" || v:val.group ==# "%s"', 
        \ g:sqs_hi_group_primary, g:sqs_hi_group_secondary))
    call matchdelete(m.id)
  endfor
endfunction

" Helpers ----------------------------------------------------------------------

" Apply the highlights for each highlight group based on pattern strings.
" Arguments are expected to be lists of two items.
function! sneak_quick_scope#apply_highlight_patterns(patterns) abort
  let [patt_p, patt_s] = a:patterns
  if !empty(patt_p)
    " Highlight columns corresponding to matched characters.
    " Ignore the leading | in the primary highlights string.
    call matchadd(g:sqs_hi_group_primary, '\v' . patt_p[1:], 
          \ g:sqs_hi_priority)

  endif
  if !empty(patt_s)
    call matchadd(g:sqs_hi_group_secondary, '\v' . patt_s[1:], 
          \ g:sqs_hi_priority)
  endif
endfunction
