
" take timeout from outside runner

" version check

if v:version < 801 || !has('patch-8.1.1310')
  echoerr 'Use vim version 8.1.1310 or above'
  cq!
endif


" settings

let &runtimepath += ',' .. (
  \   expand('<sfile>:h')
  \   ->resolve('..')
  \ )

let g:__vital_power_assert_config = {
\   '__debug__': 1
\ }

" prepare

let s:Promise = vital#vital#import('Async.Promise')

function! s:Succeed(...)
  echo 'All Tests Passed.'
  qa!
endfunction

function! s:Fail(err, ...)
  echoerr 'Test Failed.'
  echoerr a:err
  cq!
endfunction


" run

call coquille#test#runTest()
  \   .then(function('s:Succeed'))
  \   .catch(function('s:Fail'))

