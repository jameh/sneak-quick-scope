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

" The direction can be 0 (backward), 1 (forward) or 2 (both). Targets are the
" characters that can be highlighted.
function! sneak_quick_scope#HighlightView(direction, targets) abort
  if g:sqs_enable && (!exists('b:sqs_local_disable') || !b:sqs_local_disable)
    let topline = line("w0")
    let botline = line("w$")
    let line_num = line(".")
    let pos = col('.')

    " Highlight after the cursor.
    if a:direction != 0
      let [patt_p, patt_s] = s:get_highlight_patterns(line_num, botline, pos, 1,
            \ a:targets)
      call s:apply_highlight_patterns([patt_p, patt_s])
    endif

    " Highlight before the cursor.
    if a:direction != 1
      let [patt_p, patt_s] = s:get_highlight_patterns(line_num, topline, pos, 0,
            \ a:targets)
      call s:apply_highlight_patterns([patt_p, patt_s])
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

" Set or reset flags and state for highlighting on key press.
function! sneak_quick_scope#Ready() abort
  " Direction of highlight search. 0 is backward, 1 is forward
  let s:direction = 0

  " The corresponding character to f,F,t or T
  let s:target = ''

  " Position of where a dummy cursor should be placed.
  let s:cursor = 0

  " Characters with secondary highlights. Modified by get_highlight_patterns()
  let s:chars_s = []

  call s:handle_extra_highlight(2)

  " Intentionally return an empty string that will be concatenated with the
  " return values from aim(), reload() and double_tap().
  return ''
endfunction

" Returns {character motion}{captured char} (to map to a character motion) to
" emulate one as closely as possible.
function! sneak_quick_scope#Aim(motion) abort
  if (a:motion ==# 'f' || a:motion ==# 't')
    let s:direction = 1
  else
    let s:direction = 0
  endif

  " Add a dummy cursor since calling getchar() places the actual cursor on
  " the command line.
  let s:cursor = matchadd(g:sqs_hi_group_cursor, '\%#', g:sqs_hi_priority + 1)

  " Silence 'Type :quit<Enter> to exit Vim' message on <c-c> during a
  " character search.
  "
  " This line also causes getchar() to cleanly cancel on a <c-c>.
  let b:sqs_prev_ctrl_c_map = maparg('<c-c>', 'n', 0, 1)
  if empty(b:sqs_prev_ctrl_c_map)
    unlet b:sqs_prev_ctrl_c_map
  endif
  execute 'nnoremap <silent> <c-c> <c-c>'

  call sneak_quick_scope#HighlightView(s:direction, g:sqs_accepted_chars)

  redraw

  " Store and capture the target for the character motion.
  let s:target = nr2char(getchar())

  return a:motion . s:target
endfunction

" Cleanup after a character motion is executed.
function! sneak_quick_scope#Reload() abort
  " Remove dummy cursor
  call matchdelete(s:cursor)

  " Restore previous or default <c-c> functionality
  if exists('b:sqs_prev_ctrl_c_map')
    call sneak_quick_scope#mapping#Restore(b:sqs_prev_ctrl_c_map)
    unlet b:sqs_prev_ctrl_c_map
  else
    execute 'nunmap <c-c>'
  endif

  call sneak_quick_scope#UnhighlightView()

  " Intentionally return an empty string.
  return ''
endfunction

" Trigger an extra highlight for a target character only if it originally had
" a secondary highlight.
function! sneak_quick_scope#DoubleTap() abort
  if index(s:chars_s, s:target) != -1
    " Warning: slight hack below. Although the cursor has already moved by
    " this point, col('.') won't return the updated cursor position until the
    " invoking mapping completes. So when highlight_line() is called here, the
    " first occurrence of the target will be under the cursor, and the second
    " occurrence will be where the first occurence should have been.
    call sneak_quick_scope#HighlightView(s:direction, [expand(s:target)])

    " Unhighlight only primary highlights (i.e., the character under the
    " cursor).
    for m in filter(getmatches(), printf('v:val.group ==# "%s"', 
          \ g:sqs_hi_group_primary))
      call matchdelete(m.id)
    endfor

    " Temporarily change the second occurrence highlight color to a primary
    " highlight color.
    call s:save_secondary_highlight()
    execute 'highlight! link ' . g:sqs_hi_group_secondary . ' ' . 
          \ g:sqs_hi_group_primary

    " Set a temporary event to keep track of when to reset the extra
    " highlight.
    augroup sneak_quick_scope
      autocmd CursorMoved * call s:handle_extra_highlight(1)
    augroup END

    call s:handle_extra_highlight(0)
  endif

  " Intentionally return an empty string.
  return ''
endfunction

" Helpers ----------------------------------------------------------------------

" Apply the highlights for each highlight group based on pattern strings.
" Arguments are expected to be lists of two items.
function! s:apply_highlight_patterns(patterns) abort
  let [patt_p, patt_s] = a:patterns
  if !empty(patt_p)
    " Highlight columns corresponding to matched characters.
    " Ignore the leading | in the primary highlights string.
    call matchadd(g:sqs_hi_group_primary, '\v' . patt_p[1:], 
          \ g:sqs_hi_priority)
    " echom "patt_p" . patt_p
  endif
  if !empty(patt_s)
    call matchadd(g:sqs_hi_group_secondary, '\v' . patt_s[1:], 
          \ g:sqs_hi_priority)
    " echom "patt_s" . patt_s
  endif
endfunction

" Keep track of which characters have a secondary highlight (but no primary
" highlight) and store them in :chars_s. Used when g:sqs_highlight_on_keys is
" active to decide whether to trigger an extra highlight.
function! s:save_chars_with_secondary_highlights(chars) abort
  let [char_p, char_s] = a:chars

  if !empty(char_p)
    " Do nothing
  elseif !empty(char_s)
    call add(s:chars_s, char_s)
  endif
endfunction

" Set or append to the pattern strings for the highlights.
function! s:add_to_highlight_patterns(patterns, highlights, line_num) abort
  let [patt_p, patt_s] = a:patterns
  let [hi_p, hi_s] = a:highlights

  " echom 'add_to_highlight_patterns hi_p: ' . hi_p . ' hi_s: ' . hi_s

  " If there is a primary highlight for the last word, add it to the primary
  " highlight pattern.
  if hi_p > 0
    " echom "assigning to patt_p"
    let patt_p = printf('%s|%%%sl%%%sc', patt_p, a:line_num, hi_p)
  elseif hi_s > 0
    " echom "assigning to patt_s"
    let patt_s = printf('%s|%%%sl%%%sc', patt_s, a:line_num, hi_s)
  endif

  return [patt_p, patt_s]
endfunction

" Finds which characters to highlight and returns their column positions as a
" pattern string.
function! s:get_highlight_patterns(line_num, end_line_num, cursor, direction, 
      \ targets) abort

  " echom "get_highlight_patterns line num: " . a:line_num . " end line_num: " .
  "       \ a:end_line_num . " cursor: " . a:cursor . " direction: " . 
  "       \ a:direction
  " Keeps track of the number of occurrences for each target
  let occurrences = {}

  " Patterns to match the characters that will be marked with primary and
  " secondary highlight groups, respectively
  let [patt_p, patt_s] = ['', '']

  " Indicates whether this is the first word under the cursor. We don't want
  " to highlight any characters in it.
  let is_first_word = 1

   " 𠜎 𠜱 𠝹 𠱓 𠱸 𠲖 𠳏 𠳕 𠴕 𠵼 𠵿 𠸎 𠸏 𠹷 𠺝 𠺢 𠻗 𠻹 𠻺 𠼭 𠼮 𠽌 𠾴 𠾼 𠿪 𡁜 𡁯 𡁵 𡁶 𡁻 𡃁 𡃉 𡇙 𢃇 𢞵 𢫕 𢭃 𢯊 𢱑 𢱕 𢳂 𢴈 𢵌 𢵧 𢺳 𣲷 𤓓 𤶸 𤷪 𥄫 𦉘 𦟌 𦧲 𦧺 𧨾 𨅝 𨈇 𨋢 𨳊 𨳍 𨳒 𩶘

  " We want to skip the first char as this is the char the cursor is at
  let is_first_char = 1

  " The position of a character in a word that will be given a highlight. A
  " value of 0 indicates there is no character to highlight.
  let [hi_p, hi_s] = [0, 0]

  " The (next) characters that will be given a highlight. Used by
  " save_chars_with_secondary_highlights() to see whether an extra highlight
  " should be triggered if g:sqs_highlight_on_keys is active.
  let [char_p, char_s] = ['', '']

  " If direction is 1, we're looping forwards from the cursor to the end of the 
  " line; otherwise, we're looping from the cursor to the beginning of the line.
  
  let line = getline(a:line_num)
  let line_len = strlen(line)

  " find the character index i and the byte index c
  " of the current cursor position
  let c = 1
  let i = 0
  let char = ''
  while c != a:cursor
    let char = matchstr(line, '.', byteidx(line, i))
    let c += len(char)
    let i += 1
  endwhile

  " reposition cursor to end of the char's composing bytes
  if !a:direction
    let c += len(matchstr(line, '.', byteidx(line, i))) - 1
  endif

  let c_start  = c
  let l  = a:line_num
    

  let total_iter = 0

  let char = matchstr(line, '.', byteidx(line, i))

  " catch cases where multibyte chars may result in c not exactly equal to
  " line_end
  while((a:direction && l <= a:end_line_num || !a:direction && l >= a:end_line_num) && 
        \ abs(l - a:line_num) <= g:sqs_within_lines && 
        \ abs(c - c_start) <= g:sqs_within_chars)

    " echom "line: " . string(l)

    if exists('last_char')
      unlet last_char
    endif
  
    if a:direction == 1
      let line_end = line_len
    else
      let line_end = -1
    endif

    if !empty(line)
      while ((a:direction && c <= line_end || !a:direction && c >= line_end) &&
            \ abs(c - c_start) <= g:sqs_within_chars)

        let total_iter += 1


        let char = matchstr(line, '.', byteidx(line, i))
        " echom "c: " . string(c) . " char: " . char

        " Skips the first char as it is the char the cursor is at
        if is_first_char

          let is_first_char = 0

         " Don't consider the character for highlighting, but mark the position
         " as the start of a new word.
         " use '\k' to check agains keyword characters (see :help 'iskeyword' and
         " :help /\k)
        else
          if exists('last_char')
            if char !~# '\k' || empty(char)
              " echom "char is break"
              " echom "line is : " . l . " cursor line is: " . a:line_num
              if !is_first_word && (l != a:line_num || g:sqs_highlight_current_line)
                " echom "adding inside char loop"
                let [patt_p, patt_s] = s:add_to_highlight_patterns([patt_p, patt_s],
                      \ [hi_p, hi_s], l)
              endif

              " We've reached a new word, so reset any highlights.
              let [hi_p, hi_s] = [0, 0]
              let [char_p, char_s] = ['', '']

              let is_first_word = 0
            elseif index(a:targets, char) != -1 && 
                  \ index(a:targets, last_char) != -1


             if a:direction
               let concat = char . last_char
             else
               let concat = last_char . char
             endif

             if has_key(occurrences, concat)
               let occurrences[concat] += 1
             else
               let occurrences[concat] = 1
             endif

             let char_pair_occurances = get(occurrences, concat)
             if !is_first_word

               " If the search is forward, we want to be greedy; otherwise, we
               " want to be reluctant. This prioritizes highlighting for
               " characters at the beginning of a word.
               "
               " If this is the first occurrence of the letter in the word,
               " mark it for a highlight.
               " If we are looking backwards, c will point to the end of the
               " end of composing bytes so we adjust accordingly
               " eg. with a multibyte char of length 3, c will point to the
               " 3rd byte. Minus (len(char) - 1) to adjust to 1st byte
               if char_pair_occurances == 1 && ((a:direction == 1 && hi_p == 0) ||
                     \ a:direction == 0)
                 let hi_p = c - (1 - a:direction) * (len(last_char) + 
                       \ len(char) - 1)
                 let char_p = concat
               elseif char_pair_occurances == 2 && ((a:direction == 1 && hi_s == 0) ||
                     \ a:direction == 0)
                 let hi_s = c - (1 - a:direction) * (len(last_char) + 
                       \ len(char)- 1)
                 let char_s = concat
               endif
             endif
            endif
          endif
         let last_char = char
        endif

        " update i to next character
        " update c to next byteindex
        if a:direction == 1
          let i += 1
          let c += max([strlen(char), 1])
        else
          let i -= 1
          let c -= max([strlen(char), 1])
        endif
      endwhile
    endif

    let l += a:direction == 1 ? 1 : -1
    let line = getline(l)
    let line_len = strlen(line)
    if a:direction == 1
      let c = 0
      let i = 0
      let line_end = line_len
    else
      let i = line_len - 1
      let c = col([l, '$'])
      let line_end = -1
    endif
  endwhile

  echom "total_iter: " . total_iter

  let [patt_p, patt_s] = s:add_to_highlight_patterns([patt_p, patt_s],
        \ [hi_p, hi_s], l)

  "TODO
  " if exists('g:sqs_highlight_on_keys')
  "   call s:save_chars_with_secondary_highlights([char_p, char_s])
  " endif

  return [patt_p, patt_s]
endfunction

" Save the value of g:sqs_hi_group_secondary to preserve customization before
" changing it as a result of a double_tap
function! s:save_secondary_highlight() abort
  if &verbose
    let s:saved_verbose = &verbose
    set verbose=0
  endif

  redir => s:saved_secondary_highlight
  execute 'silent highlight ' . g:sqs_hi_group_secondary
  redir END

  if exists('s:saved_verbose')
    execute 'set verbose=' . s:saved_verbose
  endif

  let s:saved_secondary_highlight = substitute(s:saved_secondary_highlight,
        \ '^.*xxx ', '', '')
endfunction

" Reset g:sqs_hi_group_secondary to its saved value after it was changed as a
" result of a double_tap
function! s:reset_saved_secondary_highlight() abort
  if s:saved_secondary_highlight =~# '^links to '
    let s:saved_secondary_hlgroup_only = substitute(s:saved_secondary_highlight,
          \ '^links to ', '', '')
    execute 'highlight! link ' . g:sqs_hi_group_secondary . ' ' .
          \ s:saved_secondary_hlgroup_only
  else
    execute 'highlight ' . g:sqs_hi_group_secondary . ' ' .
          \ s:saved_secondary_highlight
  endif
endfunction

" Highlight on key press -----------------------------------------------------
" Manage state for keeping or removing the extra highlight after triggering a
" highlight on key press.
"
" State can be 0 (extra highlight has just been triggered), 1 (the cursor has
" moved while an extra highlight is active), or 2 (cancel an active extra
" highlight).
function! s:handle_extra_highlight(state) abort
  if a:state == 0
    let s:cursor_moved_count = 0
  elseif a:state == 1
    let s:cursor_moved_count = s:cursor_moved_count + 1
  endif

  " If the cursor has moved more than once since the extra highlight has been
  " active (or the state is 2), reset the extra highlight.
  if exists('s:cursor_moved_count') && (a:state == 2 || 
        \ s:cursor_moved_count > 1)
    call sneak_quick_scope#UnhighlightView()
    call s:reset_saved_secondary_highlight()
    autocmd! sneak_quick_scope CursorMoved
  endif
endfunction
