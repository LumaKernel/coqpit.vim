" =============
" Coq Langugage
" =============

let s:NOT_WHITESPACE_regex = '\v\S&[^\n\r]'
let s:COMMENT_START_regex = '\v\(\*'
let s:COMMENT_END_regex = '\v\*\)'
let s:STRING_DELIM_regex = '\v"'


" library as a language, Coq

" type Pos = [line, pos] : [int]
" type Range = {start: Pos, end: Pos}
"   NOTE: (left inclusive, right exclusive)
" type null = ** only v:null **


" Return range corresponding to one sentense.
" Assumeing sentense starts just `from_pos`.
"
" content : [string]
" from_pos : Pos
"
" return Range | null
" getNextSentenceRange(content, from_pos) {{{
function coquille#coqlang#
    \getNextSentenceRange(content, from_pos) abort
  let [line, col] = from_pos
  let end_pos = coquille#coqlang#findNextSentencePos(content, from_pos)
  if type(end_pos) == type(v:null)
    return v:null
  endif

  return {"start": from_pos, "stop": end_pos}
endfunction  " }}}


" Find next sentence after from_pos inclusive.
" Sentense is finishing with dot, one of braces, or one of dots.
" Assuming sentense can start `from_pos`.
" Returns the position right after sentence,
" namely exclusive in that line.
" Return v:null if never close sentence.
"
" Examples:
"   - findNextSentencePos(["hi."], [0, 0]) == [0, 3]
"   - findNextSentencePos([" hello."], [0, 0]) == [0, 7]
"   - findNextSentencePos(["(* oh... *)","--."], [0, 3]) == [1, 2]
"
"
" content : [string]
" from_pos : Pos
"
" return Pos | null
" findNextSentencePos(content, from_pos) {{{
function coquille#coqlang#
    \findNextSentencePos(content, from_pos) abort
  let [line, col] = from_pos
  let end_pos = s:findNextSentencePos(line, col)

  let braces = ['{', '}']
  let bullets = ['-', '+', '*']

  let blen = len(content)
  

  while line < blen
      \ && match(content[line][col:], s:NOT_WHITESPACE_regex) == -1
    let line += 1
    let col = 0
  endwhile

  if line >= blen
    return v:null

  " FIXME: keeping the stripped line would be
  while content[line][col] == ' '
    let col += 1  " more efficient. " TODO : what ?

    " Then we check if the first character of the chunk is a bullet.
    " Intially I did that only when I was sure to be in a proof (by looking in
    " [encountered_dots] whether I was after a "collapsable" chunk or not), but
    "   1/ that didn't play well with coq_to_cursor (as the "collapsable chunk"
    "      might not have been sent/detected yet).
    "   2/ The bullet chars can never be used at the *beginning* of a chunk
    "      outside of a proof. So the check was unecessary.

    if count(brances, content[line][col])
      return [line, col + 1]
    endif
    if count(bullets, content[line][col])
      let bullet = content[line][col]
      while bullet == content[line][col+1]
        let col += 1
      endwhile
      return [line, col + 1]
    endif

    " We might have a commentary before the bullet, we should be skiping it and
    " keep on looking.
    let tail_len = len(content[line]) - col

    if (tail_len - 1 > 0) && content[line][col] == '(' && content[line][col + 1] == '*'
      com_end = coquille#coqlang#skipComment(line, [col + 2, 1])

      if type(com_end) == type(v:null)
        return v:null

      return coquille#coqlang#findNextSentencePos(content, com_end)

    " If the chunk doesn't start with a bullet, we look for a dot.

    return _find_dot_after(line, col)

endfunction  " }}}


" Find next position whose nested level is zero.
" Return v:null if never close.
"
" Examples:
"   - skipComment(["hi (**) ."], [0, 0], 0) == [0, 0]
"   - skipComment([" (* *) hello"], [0, 0], 0) == [0, 0]
"   - skipComment([" (* *) hello"], [0, 3], 1) == [0, 6]
"   - skipComment([" (* ", "(*", "*)*)--"], [0, 3], 1) == [2, 4]
"   - skipComment([' (* " "" "*) "" " *) hello'], [0, 3], 1) == [0, 20]
"
"
" content : [string]
" from_pos : Pos
" nested : int
"
" return Pos | null
" skipComment(content, from_pos, nested) {{{
function coquille#coqlang#
    \skipComment(content, from_pos, nested = 1) abort
  if nested == 0
    return from_pos
  endif

  let blen = len(content)

  if line >= blen
    return v:null
  endif

  let line_str = content[line][col:]

  let next = sort([
    \   [match(line_str, s:COMMENT_START_regex), 0],
    \   [match(line_str, s:COMMENT_END_regex), 1],
    \   [match(line_str, s:STRING_DELIM_regex), 2]
    \ ])

  for token in next
    if token[0] != -1
      let col += token[0]
      if token[1] == 0
        " comment start (*
        return skipComment(content, [line, col + 2], nested - 1)
      elseif token[1] == 1
        " comment end *)
        return skipComment(content, [line, col + 2], nested + 1)
      elseif token[1] == 2
        " string start "
        let pos = skipString(content, [line, col + 1])
        return skipComment(content, pos, nested)
      endif
    endif
  endfor
  return skipComment(content, [line + 1, 0], nested)
endfunction  " }}}


" Find next position where string ends.
" Return v:null if never close.
"
" Examples:
"   - skipString(["hi (**) ."], [0, 0], 0) == [0, 0]
"   - skipString([" (* *) hello"], [0, 0], 0) == [0, 0]
"   - skipString([" (* *) hello"], [0, 3], 1) == [0, 6]
"   - skipString([" (* ", "(*", "*)*)--"], [0, 3], 1) == [2, 4]
"   - skipString([' (* " "" "*) "" " *) hello'], [0, 3], 1) == [0, 20]
"
"
" content : [string]
" from_pos : Pos
" nested : int
"
" return Pos | null
" skipString(content, from_pos) {{{
function coquille#coqlang#
    \skipString(content, from_pos) abort

  let blen = len(content)

  if line >= blen
    return v:null
  endif

  let line_str = content[line][col:]

  let str_end = match(line_str, s:STRING_DELIM_regex)

  if str_end != -1
    let col += str_end
    if len(line_str) > col + 1 && line_str[col + 1] == '"'
      return skipString(content, [line, col + 2])
    else
      return [line, col + 1]
    endif
  endif

  return skipString(content, [line + 1, 0])
endfunction  " }}}

