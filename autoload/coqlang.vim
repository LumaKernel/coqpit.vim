" =============
" Coq Langugage
" =============

" This is not strict Coq syntax analyzer.
" This makes just expections for good experience.



let s:start = function('coqpit#util#argsetup')
let s:get = function('coqpit#util#argget')
let s:end = function('coqpit#util#argend')



" - patterns

let g:coqlang#COMMENT_START = '(\*'
let g:coqlang#COMMENT_END = '\*)'
let g:coqlang#STRING_DELIM = '"'
let g:coqlang#DOT = '\.\%($\| \|\n\|\t\)\@='
let g:coqlang#GOAL_SELECTOR_START = '\[\|\d'
let g:coqlang#GOAL_SELECTOR_MIDDLE = ':'
let g:coqlang#BRACE_START = '{'


" library for Coq as a language

" type Pos = [line, pos] : [int]
" type Range = [start, end] : [Pos]
"   NOTE: (left inclusive, right exclusive)
" type null has only v:null

" Pos | null means v:null is `never closed`



" - functions

function! coqlang#is_blank(char)
  return a:char ==# ' ' || a:char ==# "\n" || a:char ==# "\t"
endfunction


" Return range corresponding to one sentense.
" Assumeing sentense starts just `from_pos`.
"
"
" content : [string]
" from_pos : Pos
"
" return Range | null
" next_sentence_range(content, from_pos) {{{
function! coqlang#next_sentence_range(content, from_pos) abort
  let [line, col] = a:from_pos
  let end_pos = coqlang#next_sentence(a:content, a:from_pos)
  if end_pos is v:null
    return v:null
  endif

  return [a:from_pos, end_pos]
endfunction
" }}}



" TODO
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" skip_blanks(content, from_pos) {{{
function! coqlang#skip_blanks(content, from_pos) abort
  if a:from_pos is v:null
    return v:null
  endif

  let [line, col] = a:from_pos
  let linenum = len(a:content)


  " reference : https://coq.inria.fr/refman/language/gallina-specification-language.html
  let blanks = ["\t", "\n", ' ']

  while line < linenum
    if col < len(a:content[line])
      if count(blanks, a:content[line][col])
        let col += 1
      else
        break
      endif
    else
      let line += 1
      let col = 0
    endif
  endwhile

  if line >= linenum
    return v:null
  endif

  return [line, col]
endfunction  " }}}

" skip_blanks(content, from_pos) {{{
function! coqlang#skip_blanks_and_comment(content, from_pos) abort
  let old_pos = [-1, -1]
  let pos = a:from_pos
  while old_pos != pos
    let old_pos = pos
    let pos = coqlang#skip_blanks(a:content, pos)
    if pos is v:null | break | endif

    if a:content[pos[0]][pos[1]:pos[1]+1] ==# '(*'
      let pos[1] += 2
      let pos = coqlang#skip_comment(a:content, pos)
    endif
    if pos is v:null | break | endif
  endwhile

  return pos
endfunction
" }}}


" Find next sentence after from_pos inclusive.
" Sentense is finishing with dot, one of braces, or one of dots.
" Assuming sentense can start `from_pos`.
" Returns the position right after sentence,
" namely exclusive in that line.
"
"
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" next_sentence(content, from_pos) {{{
function! coqlang#next_sentence(content, from_pos) abort
  let [line, col] = a:from_pos
  if line < 0
    let line = 0
    let col = 0
  endif

  while 1
    let nonblank = coqlang#skip_blanks(a:content, [line, col])
    if nonblank is v:null
      return v:null
    endif

    let [line, col] = nonblank

    " reference : https://coq.inria.fr/refman/proof-engine/proof-handling.html
    let bullets = ['-', '+', '*']

    " -- check whether encountering bullets or braces
    "  simply, we assume these as sentence even if outside proof mode
    "  it works well

    " brace start
    if a:content[line][col] ==# '{'
      return [line, col + 1]
    endif
    " possibly brace start
    if match(a:content[line][col], g:coqlang#GOAL_SELECTOR_START) == 0
      let col += 1
      let pos = coqlang#next_pattern(a:content, [line, col], g:coqlang#GOAL_SELECTOR_MIDDLE)
      if pos is v:null
        let pos = [line, col]
      endif
      let pos = coqlang#skip_blanks_and_comment(a:content, pos)
      if pos is v:null
        return v:null
      endif
      if a:content[pos[0]][pos[1]] ==# '{'
        let pos[1] += 1
        return pos
      endif
      let pos = coqlang#next_pattern(a:content, pos, g:coqlang#DOT)
      return pos
    endif
    " brace end
    if a:content[line][col] ==# '}'
      return [line, col + 1]
    endif
    " bullets
    if count(bullets, a:content[line][col])
      let bullet = a:content[line][col]
      while bullet ==# a:content[line][col + 1]
        let col += 1
      endwhile
      return [line, col + 1]
    endif

    " -- skip commentary when encountered it
    "  before finding the sentence beginning
    let tail_len = len(a:content[line]) - col

    if a:content[line][col:col+1] ==# '(*'
      let com_end = coqlang#skip_comment(a:content, [line, col + 2])

      if com_end is v:null
        return v:null
      endif

      let [line, col] = com_end
      continue
    endif

    return coqlang#next_pattern(a:content, [line, col], g:coqlang#DOT)
  endwhile
endfunction
" }}}


" Find next position whose nested level is zero. (exclusive)
" Return v:null if never close.
"
"
" content : [string]
" from_pos : Pos | null
" nested = 1 : int
"
" return Pos | null
" skip_comment(content, from_pos, nested = 1) {{{
function! coqlang#skip_comment(content, from_pos, ...) abort
  call s:start(a:000)
  let nested = s:get(1)
  call s:end()
  let [line, col] = a:from_pos
  if line < 0
    let line = 0
    let col = 0
  endif

  while nested > 0
    let nonblank_pos = coqlang#skip_blanks(a:content, [line, col])
    if nonblank_pos is v:null
      return v:null
    endif

    let [line, col] = nonblank_pos

    let trail = a:content[line][col:]

    let next = sort([
          \   [match(trail, g:coqlang#COMMENT_START), 0],
          \   [match(trail, g:coqlang#COMMENT_END), 1],
          \   [match(trail, g:coqlang#STRING_DELIM), 2]
          \ ], function('s:pos_cmp'))

    let matched = 0
    for token in next
      if token[0] != -1
        let col += token[0]
        if token[1] == 0
          " comment start (*
          let nested += 1
          let col += 2
          let matched = 1
          break
        elseif token[1] == 1
          " comment end *)
          let nested -= 1
          let col += 2
          let matched = 1
          break
        elseif token[1] == 2
          " string start "
          let pos = coqlang#skip_string(a:content, [line, col + 1])
          if pos is v:null
            return v:null
          endif

          let [line, col] = pos
          let matched = 1
          break
        endif
      endif
    endfor
    if !matched
      let line += 1
      let col = 0
    endif
  endwhile
  return [line, col]
endfunction  " }}}


" Find next position where string ends. (exclusive)
" Return v:null if never close.
"
"
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" skip_string(content, from_pos) {{{
function! coqlang#skip_string(content, from_pos) abort
  let [line, col] = a:from_pos

  while 1
    if line >= len(a:content)
      return v:null
    endif

    let trail = a:content[line][col:]

    let str_end = match(trail, g:coqlang#STRING_DELIM)

    if str_end != -1
      let col += str_end
      if len(trail) > str_end + 1 && trail[str_end + 1] ==# '"'
        let col += 2
        continue
      else
        return [line, col + 1]
      endif
    endif

    let line += 1
    let col = 0
  endwhile
endfunction  " }}}



" Find next end pos of pattern appearing
"   with skipping comments and strings.
"
" content : [string]
" from_pos : Pos | null
" pattern : string
"
" return Pos | null
" next_pattern(content, from_pos, pattern) {{{
function! coqlang#next_pattern(content, from_pos, pattern) abort
  let [line, col] = a:from_pos
  if line < 0
    let line = 0
    let col = 0
  endif

  while 1
    if line >= len(a:content)
      return v:null
    endif

    let trail = a:content[line][col:]

    let next = sort([
          \   [match(trail, g:coqlang#COMMENT_START), 0],
          \   [match(trail, g:coqlang#STRING_DELIM), 1],
          \   [match(trail, a:pattern), 2]
          \ ], function('s:pos_cmp'))

    let matched = 0
    for token in next
      if token[0] != -1
        let col += token[0]
        if token[1] == 0
          " comment start (*
          let pos = coqlang#skip_comment(a:content, [line, col + 2])
          if pos is v:null
            retur v:null
          endif
          let [line, col] = pos
          let matched = 1
          break
        elseif token[1] == 1
          " string start "
          let pos = coqlang#skip_string(a:content, [line, col + 1])
          if pos is v:null
            return v:null
          endif

          let [line, col] = pos
          let matched = 1
          break
        elseif token[1] == 2
          " pattern
          return [line, col + 1]
        endif
      endif
    endfor
    if !matched
      let line += 1
      let col = 0
    endif
  endwhile
endfunction  " }}}


" internal


function! s:pos_cmp(pos1, pos2) abort
  return a:pos1[0] != a:pos2[0] ? a:pos1[0] - a:pos2[0] : a:pos1[1] - a:pos2[1]
endfunction
