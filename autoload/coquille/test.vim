
let s:Promise = vital#vital#import('Async.Promise')

function! coquille#test#runTest()
  return s:Promise({resolve->
        \ [
        \   coqlang#Test(),
        \   coquille#color#Test(),
        \   coquille#IDE#Test(),
        \   coquille#annotate#Test(),
        \   resolve()
        \ ]})
endfunction

