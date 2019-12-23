

let s:PowerAssert = vital#vital#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert


" Returns associated pos exclusive
"
" xml : XML
" content : [string]
" from_pos : Pos
"
" return Pos
function! coquille#annotate#associate(xml, content, from_pos) abort
  " count non-space characters with pairing and return last positoin

  let sentence = coquille#xml#2str(a:xml)
  let now_pos = a:from_pos

  let now = 0
  while now < strlen(sentence)
    exe s:assert('now_pos[0] < len(a:content)')
    let now_pos = coqlang#skip_blanks_and_comment(a:content, now_pos)
    exe s:assert('now_pos isnot v:null')

    while now_pos[1] >= len(a:content[now_pos[0]])
      let now_pos[1] = 0
      let now_pos[0] += 1
    endwhile

    if sentence[now] ==# '"'
      let pos = coqlang#skip_string([sentence], [0, now + 1])
      exe s:assert('pos isnot v:null')
      let now = pos[1]

      let now_pos[1] += 1
      let now_pos = coqlang#skip_string(a:content, now_pos)
      exe s:assert('now_pos isnot v:null')

      continue
    elseif !(sentence[now] =~# '\_s') && sentence[now] ==# a:content[now_pos[0]][now_pos[1]]
      let now_pos[1] += 1
    endif

    let now += 1
  endwhile

  return now_pos
endfunction



function! coquille#annotate#Test()
  PAssert coquille#annotate#associate('', ['bar.'], [0, 0]) == [0, 0]
  PAssert coquille#annotate#associate('abc', ['a','bc', 'yo.'], [0, 0]) == [1, 2]
  PAssert coquille#annotate#associate('a b c .', ['a (* *)','bc .'], [0, 0]) == [1, 4]
  PAssert coquille#annotate#associate('a b c .', ['a (**)','(* *) bc .', 'wow.'], [0, 0]) == [1, 10]
  PAssert coquille#annotate#associate('abc.', ['a (*foo*)','(* *) bc . foo', '.'], [0, 0]) == [1, 10]
  PAssert coquille#annotate#associate('abc "efg".', ['abc (**) "efg"', '','(* *) . hi.'], [0, 0]) == [2, 7]
  PAssert coquille#annotate#associate('abc " e fg".', ['abc (**) " e fg"', '','(* *) .  (* *)'], [0, 0]) == [2, 7]
  PAssert coquille#annotate#associate('abc " e (*fg".', ['abc (**) " e (*fg"', '','(* *) .', '', ''], [0, 0]) == [2, 7]
endfunction


