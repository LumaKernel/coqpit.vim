
function! coquille#color#defineColorScheme() abort
  ECHO "colo"
  let bg_tup = s:toTuple(synIDattr(hlID('Normal'), 'bg#'))

  let coq_checked_bg = s:toString(s:col_mult(bg_tup, [1, 1, 2.2]))
  let coq_checked_axiom_bg = s:toString(s:col_mult(bg_tup, [3.5, 1.8, 0.8]))
  let coq_queued_bg  = s:toString(s:col_mult(bg_tup, [1.2, 1.8, 1.2]))
  " let coq_checked_warn_bg       = s:toString(s:col_mult(bg_tup, [3, 2, 1]))

  exe 'hi default CoqChecked      ctermbg=20  guibg=' .. coq_checked_bg
  exe 'hi default CoqCheckedAxiom ctermbg=184 guibg=' .. coq_checked_axiom_bg
  exe 'hi default CoqQueued       ctermbg=40  guibg=' .. coq_queued_bg
  exe 'hi default CoqMarkedWarn   ctermbg=172 gui=undercurl guisp=Yellow'
  exe 'hi default CoqCheckedWarn  ctermbg=172 gui=undercurl guisp=Yellow guibg=' .. coq_checked_bg
  exe 'hi default CoqMarkedError  ctermbg=160 gui=undercurl guisp=Red'
  exe 'hi default CoqCheckedError ctermbg=160 gui=undercurl guisp=Red guibg=' .. coq_checked_bg
endfunction


" string to tuple
function! s:toTuple(text) abort
  return [str2nr(a:text[1:2], 16), str2nr(a:text[3:4], 16), str2nr(a:text[5:6], 16)]
endfunction

function! s:col_mult(tup, mul) abort
  return map(range(3), {idx -> min([max([float2nr(a:tup[idx] * a:mul[idx]), 0]), 255])})
endfunction

" tuple to string
function! s:toString(tup) abort
  return '#' .. printf('%02x', a:tup[0]) .. printf('%02x', a:tup[1]) .. printf('%02x', a:tup[2])
endfunction



function! coquille#color#Test()
  exe g:PAssert('s:toTuple("#ABCDEF") == [171, 205, 239]')
  exe g:PAssert('s:toString([171, 205, 239]) ==? "#abcdef"')
endfunction
