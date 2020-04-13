

let s:PowerAssert = vital#coquille#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert



let s:possibly_end = [
      \   '{', '}', '\-\%(>\)\@!', '+', '\*', '\.'
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
      " `sentence` doesn't include comment
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

function! coquille#annotate#is_ending(content, pos)
  let now_pos = coqlang#next_pattern(a:content, a:pos, s:possibles)
  return now_pos isnot v:null
endfunction
