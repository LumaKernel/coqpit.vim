" =============
" Coq Langugage
" =============


let s:NOT_WHITESPACE_regex = '\v\S&[^\n\r]'
let s:COMMENT_START_regex = '\v\(\*'
let s:COMMENT_END_regex = '\v\*\)'
let s:STRING_DELIM_regex = '\v"'
let s:DOT_regex = '\v\.'


" library for Coq as a language

" type Pos = [line, pos] : [int]
" type Range = [start, end] : [Pos]
"   NOTE: (left inclusive, right exclusive)
" type null = ** only v:null **



" Return range corresponding to one sentense.
" Assumeing sentense starts just `from_pos`.
"
" content : [string]
" from_pos : Pos
"
" return Range | null
" nextSentenceRange(content, from_pos) {{{
function! coqlang#nextSentenceRange(content, from_pos) abort
  let [line, col] = a:from_pos
  let end_pos = coqlang#nextSentencePos(a:content, a:from_pos)
  if type(end_pos) == v:t_none
    return v:null
  endif

  return [a:from_pos, end_pos]
endfunction  " }}}



" TODO
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" skipBlanks(content, from_pos) {{{
function! coqlang#skipBlanks(content, from_pos) abort
  if type(a:from_pos) == v:t_none
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



" Find next sentence after from_pos inclusive.
" Sentense is finishing with dot, one of braces, or one of dots.
" Assuming sentense can start `from_pos`.
" Returns the position right after sentence,
" namely exclusive in that line.
" Return v:null if never close sentence.
"
" Examples:
"   - nextSentencePos(["hi."], [0, 0]) == [0, 3]
"   - nextSentencePos([" hello."], [0, 0]) == [0, 7]
"   - nextSentencePos(["(* oh... *)","--."], [0, 3]) == [1, 2]
"
"
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" nextSentencePos(content, from_pos) {{{
function! coqlang#nextSentencePos(content, from_pos) abort
  let nonblank_pos = coqlang#skipBlanks(a:content, a:from_pos)
  if type(nonblank_pos) == v:t_none
    return v:null
  endif

  let [line, col] = nonblank_pos

  " reference : https://coq.inria.fr/refman/proof-engine/proof-handling.html
  let braces = ['{', '}']
  let bullets = ['-', '+', '*']

  " -- check whether encountering bullets or braces
  "  simply, we assume these as sentence even if outside proof mode
  "  it works well

  if count(braces, a:content[line][col])
    return [line, col + 1]
  endif
  if count(bullets, a:content[line][col])
    let bullet = a:content[line][col]
    while bullet == a:content[line][col + 1]
      let col += 1
    endwhile
    return [line, col + 1]
  endif

  " -- skip commentary when encountered it
  "  before finding the sentence beginning
  let tail_len = len(a:content[line]) - col

  if a:content[line][col:col+2] == '(*'
    let com_end = coqlang#skipComment(content, [line, col + 2])

    if type(com_end) == v:t_none
      return v:null
    endif

    return coqlang#nextSentencePos(a:content, com_end)
  endif

  return coqlang#nextDot(a:content, [line, col])
endfunction  " }}}


" Find next position whose nested level is zero. (exclusive)
" Return v:null if never close.
"
" Examples:
"   - skipComment(["hi (**) ."], [0, 0], 0) == [0, 0]
"   - skipComment([" (* *) hello"], [0, 0], 0) == [0, 0]
"   - skipComment([" (* *) hello"], [0, 3]) == [0, 6]
"   - skipComment([" (* ", "(*", "*)*)--"], [0, 3]) == [2, 4]
"   - skipComment([' (* " "" "*) "" " *) hello'], [0, 3]) == [0, 20]
"
"
" content : [string]
" from_pos : Pos | null
" nested = 1 : int
"
" return Pos | null
" skipComment(content, from_pos, nested) {{{
function! coqlang#skipComment(content, from_pos, nested = 1) abort
  if a:nested == 0
    return a:from_pos
  endif

  let nonblank_pos = coqlang#skipBlanks(a:content, a:from_pos)
  if type(nonblank_pos) == v:t_none
    return v:null
  endif

  let [line, col] = nonblank_pos

  let trail = a:content[line][col:]

  let next = sort([
    \   [match(trail, s:COMMENT_START_regex), 0],
    \   [match(trail, s:COMMENT_END_regex), 1],
    \   [match(trail, s:STRING_DELIM_regex), 2]
    \ ])

    for token in next
    if token[0] != -1
      let col += token[0]
      if token[1] == 0
        " comment start (*
        return coqlang#skipComment(a:content, [line, col + 2], a:nested + 1)
      elseif token[1] == 1
        " comment end *)
        return coqlang#skipComment(a:content, [line, col + 2], a:nested - 1)
      elseif token[1] == 2
        " string start "
        let pos = coqlang#skipString(a:content, [line, col + 1])
        return coqlang#skipComment(a:content, pos, a:nested)
      endif
    endif
  endfor
  return coqlang#skipComment(a:content, [line + 1, 0], a:nested)
endfunction  " }}}


" Find next position where string ends. (exclusive)
" Return v:null if never close.
"
" Examples:
"   - skipString(['" "yo.'], [0, 1]) == [0, 3]
"   - skipString([' " ""', ' "" " hi'], [0, 2]) == [1, 5]
"
"
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" skipString(content, from_pos) {{{
function! coqlang#skipString(content, from_pos) abort
  let nonblank_pos = coqlang#skipBlanks(a:content, a:from_pos)
  if type(nonblank_pos) == v:t_none
    return v:null
  endif

  let [line, col] = nonblank_pos

  let trail = a:content[line][col:]

  let str_end = match(trail, s:STRING_DELIM_regex)

  if str_end != -1
    let col += str_end
    if len(trail) > str_end + 1 && trail[str_end + 1] == '"'
      return coqlang#skipString(a:content, [line, col + 2])
    else
      return [line, col + 1]
    endif
  endif

  return coqlang#skipString(a:content, [line + 1, 0])
endfunction  " }}}


" Find next position where dot appears. (exclusive)
" Return v:null if never appears.
"
" Examples:
"   - nextDot(["Hi."], [0, 0]) == [0, 3]
"   - nextDot(["Hi (* yay *)", ' " *) hi" .'], [0, 4]) == [1, 8]
"
"
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" nextDot(content, from_pos) {{{
function! coqlang#nextDot(content, from_pos) abort
  let nonblank_pos = coqlang#skipBlanks(a:content, a:from_pos)
  if type(nonblank_pos) == v:t_none
    return v:null
  endif

  let [line, col] = nonblank_pos

  let trail = a:content[line][col:]

  let next = sort([
    \   [match(trail, s:COMMENT_START_regex), 0],
    \   [match(trail, s:STRING_DELIM_regex), 1],
    \   [match(trail, s:DOT_regex), 2]
    \ ])

  for token in next
    if token[0] != -1
      let col += token[0]
      if token[1] == 0
        " comment start (*
        let com_end = coqlang#skipComment(a:content, [line, col + 2])
        return coqlang#nextDot(a:content, com_end)
      elseif token[1] == 1
        " string start "
        let com_end = coqlang#skipString(a:content, [line, col + 1])
        return coqlang#nextDot(a:content, com_end)
      elseif token[1] == 2
        " dot
        return [line, col + 1]
      endif
    endif
  endfor
  return coqlang#nextDot(a:content, [line + 1, 0])
endfunction  " }}}



function! coqlang#Test()
  call assert_equal(coqlang#nextSentencePos(["hi."], [0, 0]), [0, 3])
  call assert_equal(coqlang#nextSentencePos([" hello."], [0, 0]), [0, 7])
  call assert_equal(coqlang#nextSentencePos(["(* oh... *)","--."], [0, 3]), [1, 2])

  call assert_equal(coqlang#skipComment(["hi (**) ."], [0, 0], 0), [0, 0])
  call assert_equal(coqlang#skipComment([" (* *) hello"], [0, 0], 0), [0, 0])
  call assert_equal(coqlang#skipComment([" (* *) hello"], [0, 3]), [0, 6])
  call assert_equal(coqlang#skipComment([" (* ", "(*", "*)*)--"], [0, 3]), [2, 4])
  call assert_equal(coqlang#skipComment([' (* " "" "*) "" " *) hello'], [0, 3]), [0, 20])

  call assert_equal(coqlang#skipString(['" "yo.'], [0, 1]), [0, 3])
  call assert_equal(coqlang#skipString([' " ""', ' "" " hi'], [0, 2]), [1, 5])

  call assert_equal(coqlang#nextDot(["Hi."], [0, 0]), [0, 3])
  call assert_equal(coqlang#nextDot(["Hi (* yay *)", ' " *) hi" .'], [0, 4]), [1, 8])
endfunction

