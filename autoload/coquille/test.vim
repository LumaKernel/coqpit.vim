let s:testFn = []

function! coquille#test#addTestFn(Fn) abort
  call add(s:testFn, a:Fn)
endfunction!

function! coquille#test#runTest() abort
  for l:Fn in s:testFn
    call l:Fn()
  endfor
endfunction

