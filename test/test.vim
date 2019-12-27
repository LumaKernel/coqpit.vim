" take timeout from outside runner

" version check

if v:version < 801 || !has('patch-8.1.1310')
  echoerr 'Use vim version 8.1.1310 or above'
  cq!
endif

" settings

source $VIMRUNTIME/defaults.vim


" it is not supported by VimL parser in PowerAssert
" scriptversion 2

let &runtimepath ..= ',' .. resolve(expand('<sfile>:h') .. '/..')

" prepare

function! s:Succeed(...)
  silent! !echo All Tests Passed.
  qa!
endfunction

function! s:Fail(err, ...)
  silent! !echo Test Failed.
  silent! !echo
  if type(a:err) == v:t_dict
    silent! exe '!echo ' .. shellescape('Exception: ' .. string(get(a:err, 'exception', 'none')), 1)
    silent! exe '!echo ' .. shellescape('Throwpoint: ' .. string(get(a:err, 'throwpoint', 'none')), 1)
  endif
  cq!
endfunction


" run

silent! call coquille#test#runTest()
      \.then(function('s:Succeed'))
      \.catch(function('s:Fail'))

