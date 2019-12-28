
let s:Promise = vital#coquille#import('Async.Promise')


function! coquille#test#runTest()
  let g:__vital_power_assert_config = {
  \   '__debug__': 1
  \ }

  let s:PowerAssert = vital#coquille#import('Vim.PowerAssert')
  let g:PAssert = s:PowerAssert.assert
  exe s:PowerAssert.define('PAssert')

  return s:Promise.new({resolve->
       \ [
       \   coqlang#Test(),
       \   coquille#color#Test(),
       \   coquille#IDE#Test(),
       \   coquille#annotate#Test(),
       \   resolve()
       \ ]})
endfunction

