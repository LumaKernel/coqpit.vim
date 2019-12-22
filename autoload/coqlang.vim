" =============
" Coq Langugage
" =============


let s:COMMENT_START_regex = '(\*'
let s:COMMENT_END_regex = '\*)'
let s:STRING_DELIM_regex = '"'
let s:DOT_regex = '\.\%($\| \|\n\|\t\)'
let s:BEFORE_BRACE_START_regex = '\[\|\d\|{'
let s:BRACE_START_regex = '{'


" library for Coq as a language

" type Pos = [line, pos] : [int]
" type Range = [start, end] : [Pos]
"   NOTE: (left inclusive, right exclusive)
" type null = ** only v:null **


function! coqlang#is_blank(char)
  return a:char == ' ' || a:char == "\n" || a:char == "\t"
endfunction


" Return range corresponding to one sentense.
" Assumeing sentense starts just `from_pos`.
"
"
" content : [string]
" from_pos : Pos
"
" return Range | null
" nextSentenceRange(content, from_pos) {{{
function! coqlang#nextSentenceRange(content, from_pos) abort
  let [line, col] = a:from_pos
  let end_pos = coqlang#nextSentencePos(a:content, a:from_pos)
  if end_pos is v:null
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



" Find next sentence after from_pos inclusive.
" Sentense is finishing with dot, one of braces, or one of dots.
" Assuming sentense can start `from_pos`.
" Returns the position right after sentence,
" namely exclusive in that line.
" Return v:null if never close sentence.
"
"
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" nextSentencePos(content, from_pos) {{{
function! coqlang#nextSentencePos(content, from_pos) abort
  let nonblank_pos = coqlang#skipBlanks(a:content, a:from_pos)
  if nonblank_pos is v:null
    return v:null
  endif

  let [line, col] = nonblank_pos

  " reference : https://coq.inria.fr/refman/proof-engine/proof-handling.html
  let bullets = ['-', '+', '*']

  " -- check whether encountering bullets or braces
  "  simply, we assume these as sentence even if outside proof mode
  "  it works well

  " brace start
  if match(a:content[line][col], s:BEFORE_BRACE_START_regex) == 0
    return coqlang#nextBraceStart(a:content, [line, col])
  endif
  " brace end
  if a:content[line][col] == '}'
    return [line, col + 1]
  endif
  " bullets
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

  if a:content[line][col:col+1] == '(*'
    let com_end = coqlang#skipComment(a:content, [line, col + 2])

    if com_end is v:null
      return v:null
    endif

    return coqlang#nextSentencePos(a:content, com_end)
  endif

  return coqlang#nextDot(a:content, [line, col])
endfunction  " }}}


" Find next position whose nested level is zero. (exclusive)
" Return v:null if never close.
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
  if nonblank_pos is v:null
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
"
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" skipString(content, from_pos) {{{
function! coqlang#skipString(content, from_pos) abort
  let nonblank_pos = coqlang#skipBlanks(a:content, a:from_pos)
  if nonblank_pos is v:null
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
" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" nextDot(content, from_pos) {{{
function! coqlang#nextDot(content, from_pos) abort
  let nonblank_pos = coqlang#skipBlanks(a:content, a:from_pos)
  if nonblank_pos is v:null
    return v:null
  endif

  let [line, col] = nonblank_pos

  let trail = a:content[line][col:]

  let next = sort([
    \   [match(trail, s:COMMENT_START_regex), 0],
    \   [match(trail, s:STRING_DELIM_regex), 1],
    \   [match(trail, s:DOT_regex), 2],
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
        let str_end = coqlang#skipString(a:content, [line, col + 1])
        return coqlang#nextDot(a:content, str_end)
      elseif token[1] == 2
        " before dot
        return [line, col + 1]
      endif
    endif
  endfor
  return coqlang#nextDot(a:content, [line + 1, 0])
endfunction  " }}}


" content : [string]
" from_pos : Pos | null
"
" return Pos | null
" nextBraceStart(content, from_pos) {{{
function! coqlang#nextBraceStart(content, from_pos) abort
  let nonblank_pos = coqlang#skipBlanks(a:content, a:from_pos)
  if nonblank_pos is v:null
    return v:null
  endif

  let [line, col] = nonblank_pos

  let trail = a:content[line][col:]

  let next = sort([
    \   [match(trail, s:COMMENT_START_regex), 0],
    \   [match(trail, s:STRING_DELIM_regex), 1],
    \   [match(trail, s:BRACE_START_regex), 2]
    \ ])

  for token in next
    if token[0] != -1
      let col += token[0]
      if token[1] == 0
        " comment start (*
        let com_end = coqlang#skipComment(a:content, [line, col + 2])
        return coqlang#nextBraceStart(a:content, com_end)
      elseif token[1] == 1
        " string start "
        let str_end = coqlang#skipString(a:content, [line, col + 1])
        return coqlang#nextBraceStart(a:content, str_end)
      elseif token[1] == 2
        " brance end
        return [line, col + 1]
      endif
    endif
  endfor
  return coqlang#nextBraceStart(a:content, [line + 1, 0])
endfunction  " }}}


function! coqlang#Test()
  PAssert coqlang#skipComment(["hi (**) ."], [0, 0], 0) == [0, 0]
  PAssert coqlang#skipComment([" (* *) hello"], [0, 0], 0) == [0, 0]
  PAssert coqlang#skipComment([" (* *) hello"], [0, 3]) == [0, 6]
  PAssert coqlang#skipComment([" (* ", "(*", "*)*)--"], [0, 3]) == [2, 4]
  PAssert coqlang#skipComment([' (* " "" *) "" " *) hello'], [0, 3]) == [0, 19]
  PAssert coqlang#skipComment(['(**', ')'], [0, 2]) is v:null
  PAssert coqlang#skipComment(['(**', '(*', '*)'], [0, 2]) is v:null

  PAssert coqlang#skipString(['" "yo.'], [0, 1]) == [0, 3]
  PAssert coqlang#skipString([' " ""', ' "" " hi'], [0, 2]) == [1, 5]
  PAssert coqlang#skipString(['""'], [0, 1]) == [0, 2]
  PAssert coqlang#skipString(['"'], [0, 1]) is v:null
  PAssert coqlang#skipString(['"', '"'], [0, 1]) == [1, 1]
  PAssert coqlang#skipString(['"""', '""'], [0, 1]) is v:null

  PAssert coqlang#nextDot(["Hi."], [0, 0]) == [0, 3]
  PAssert coqlang#nextDot(["Hi (* yay *)", ' " *) hi" .'], [0, 4]) == [1, 11]
  PAssert coqlang#nextDot(["ya.", "", "hi. x", "wo."], [0, 3]) == [2, 3]
  PAssert coqlang#nextDot(['', "Compute 1."], [0, 0]) == [1, 10]

  PAssert coqlang#nextBraceStart(['{'], [0, 0]) == [0, 1]
  PAssert coqlang#nextBraceStart(['{(**)'], [0, 0]) == [0, 1]
  PAssert coqlang#nextBraceStart(['0 : {'], [0, 0]) == [0, 5]
  PAssert coqlang#nextBraceStart(['13:(**){'], [0, 0]) == [0, 8]
  PAssert coqlang#nextBraceStart(['[(**)foo  ]: (*}*){'], [0, 0]) == [0, 19]
  PAssert coqlang#nextBraceStart(['[ f_o_o(*', ' {{*) ] (* *) :{(* *)'], [0, 0]) == [1, 16]
  PAssert coqlang#nextBraceStart(["[ ふー'", ' (*}]*)] (* *) :{(* *)'], [0, 0]) == [1, 17]

  PAssert coqlang#nextSentencePos(["hi."], [0, 0]) == [0, 3]
  PAssert coqlang#nextSentencePos(["ya.", "", "hi. x", "wo."], [0, 3]) == [2, 3]
  PAssert coqlang#nextSentencePos(["hi.hey."], [0, 0]) == [0, 7]
  PAssert coqlang#nextSentencePos(["hi.\they."], [0, 0]) == [0, 3]
  PAssert coqlang#nextSentencePos(["hi.","hey."], [0, 0]) == [0, 3]
  PAssert coqlang#nextSentencePos(["hi.(**)hey."], [0, 0]) == [0, 11]
  PAssert coqlang#nextSentencePos([" hello."], [0, 0]) == [0, 7]
  PAssert coqlang#nextSentencePos(["(* oh... *)","--."], [0, 0]) == [1, 2]
  PAssert coqlang#nextSentencePos(["Axiom A.", "Variable B:Prob."], [0, 0]) == [0, 8]
  PAssert coqlang#nextSentencePos(["", "Axiom A.", "Variable B:Prob."], [0, 0]) == [1, 8]
  PAssert coqlang#nextSentencePos(["ya.", "", "Axiom A.", "Variable B:Prob."], [0, 3]) == [2, 8]
  PAssert coqlang#nextSentencePos(["-", "Axiom A.", "Variable B:Prob."], [0, 0]) == [0, 1]
  PAssert coqlang#nextSentencePos(["-", "Axiom A.", "Variable B:Prob."], [1, 0]) == [1, 8]
  PAssert coqlang#nextSentencePos(["ya.", "", "Axiom A.", "Variable B:Prob."], [0, 3]) == [2, 8]
  PAssert coqlang#nextSentencePos(['', "Compute 1."], [0, 0]) == [1, 10]
  PAssert coqlang#nextSentencePos(['(*  *)', "Compute 1."], [0, 0]) == [1, 10]
  PAssert coqlang#nextSentencePos(['(* "*)" *)', "Compute 1."], [0, 0]) == [1, 10]
  PAssert coqlang#nextSentencePos(['(**){(**)'], [0, 0]) == [0, 5]
  PAssert coqlang#nextSentencePos(['(**)}(**)'], [0, 0]) == [0, 5]
  PAssert coqlang#nextSentencePos(['{simpl.'], [0, 0]) == [0, 1]
  PAssert coqlang#nextSentencePos(['{-'], [0, 0]) == [0, 1]
  PAssert coqlang#nextSentencePos(['-{'], [0, 0]) == [0, 1]
  PAssert coqlang#nextSentencePos(['}simpl.'], [0, 0]) == [0, 1]
  PAssert coqlang#nextSentencePos(['}-'], [0, 0]) == [0, 1]
  PAssert coqlang#nextSentencePos(['-}'], [0, 0]) == [0, 1]
  PAssert coqlang#nextSentencePos(['--}'], [0, 0]) == [0, 2]
  PAssert coqlang#nextSentencePos(['(**)[a]:{simpl.'], [0, 0]) == [0, 9]
  " Hiragana is basically represented by 3 bytes in utf-8
  PAssert coqlang#nextSentencePos(['(**)[fooわおbar]:{simpl.'], [0, 0]) == [0, 20]
  PAssert coqlang#nextSentencePos(["(**)[__123__''(*'", '*)', ']:{(**)bar.'], [0, 0]) == [2, 3]

  PAssert coqlang#nextSentencePos(['A.', '', 'C. D. (* *)', 'E.'], [0, 2]) == [2, 2]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'C. D. (* *)', 'E.'], [0, 2]) == [3, 2]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'C x. D. (* *)', 'E.'], [0, 2]) == [3, 4]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'C. D. (* *)', '', 'E.'], [0, 2]) == [3, 2]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'C x. D. (* *)', '', 'E.'], [0, 2]) == [3, 4]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'CC . DD. (* *)', '', 'E.'], [0, 2]) == [3, 4]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'CC x. (* *)', '', 'E.'], [0, 2]) == [3, 5]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'CC x. D. (* *)', '', 'E.'], [0, 2]) == [3, 5]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'CC x. DD. (* *)', '', 'E.'], [0, 2]) == [3, 5]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'CC xx. DD. (* *)', '', 'E.'], [0, 2]) == [3, 6]
  PAssert coqlang#nextSentencePos(['A.', '', '', 'Goal True. Admitted. (* *)', '', 'E.'], [0, 2]) == [3, 10]
endfunction
