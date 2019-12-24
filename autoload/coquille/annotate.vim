

let s:PowerAssert = vital#vital#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert



let s:possibly_end = [
      \   '{', '}', '\-', '+', '\*', '\.'
      \ ]

let s:possibles = join(s:possibly_end, '\|')


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

    let now_pos = coqlang#next_pattern(a:content, now_pos, s:possibles)
    exe s:assert('now_pos isnot v:null')
    exe s:assert('now_pos[1] >= 1')

    while sentence[now] !=# a:content[now_pos[0]][now_pos[1] - 1]
      " `sentence` does'nt include comment
      if sentence[now] ==# '"'
        let pos = coqlang#skip_string([sentence], [0, now + 1])
        exe s:assert('pos isnot v:null')

        let now = pos[1]
      else
        let now += 1
      endif
      exe s:assert('now < len(sentence)')
    endwhile

    let now += 1
  endwhile

  return now_pos
endfunction



function! coquille#annotate#Test()
  PAssert coquille#annotate#associate('', ['bar.'], [0, 0]) == [0, 0]
  PAssert coquille#annotate#associate('a b c .', ['a (* *)','bc .'], [0, 0]) == [1, 4]
  PAssert coquille#annotate#associate('a b c .', ['a (**)','(* *) bc .', 'wow.'], [0, 0]) == [1, 10]
  PAssert coquille#annotate#associate('abc.', ['a (*foo*)','(* *) bc . foo', '.'], [0, 0]) == [1, 10]
  PAssert coquille#annotate#associate('abc "efg".', ['abc (**) "efg"', '','(* *) . hi.'], [0, 0]) == [2, 7]
  PAssert coquille#annotate#associate('abc " e fg".', ['abc (**) " e fg"', '','(* *) .  (* *)'], [0, 0]) == [2, 7]
  PAssert coquille#annotate#associate('abc " e (*fg".', ['abc (**) " e (*fg"', '','(* *) .', '', ''], [0, 0]) == [2, 7]
endfunction


