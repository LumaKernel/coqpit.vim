" take timeout from outside runner

" version check

if v:version < 800
  silent! exe '!echo ' . shellescape('Use Vim version 8.0 or above, or Neovim', 1)
  cq!
endif


" utility

function! Echo(str)
  silent! exe '!echo ' .. shellescape(a:str, 1)
endfunction


" settings

let &runtimepath = resolve(expand('<sfile>:h') .. '/..') .. ',' .. &runtimepath
source $VIMRUNTIME/defaults.vim


let s:Promise = vital#coquille#import('Async.Promise')

function! s:wait(ms)
  return s:Promise.new({resolve -> timer_start(a:ms, resolve)})
endfunction

function! s:next_tick()
  return s:wait(0)
endfunction

let s:dir = expand('<sfile>:h')

function! s:EditAndWait(...) abort
  exe 'edit ' .. resolve(s:dir .. '/../dev/coq-examples/eg_proof_handling.v')
  CoqLaunch
  call coquille#check_running()
  CoqToLast

  function! s:waitEnd(ms)
    return s:wait(a:ms)
      \.then({-> [
      \   coquille#check_running(),
      \   len(b:coquilleIDE.queue),
      \   ][-1] != 0 ? s:waitEnd(a:ms) : 0
      \ })
  endfunction

  return s:waitEnd(1000)
endfunction


" process messages

function! s:Succeed(...)
  call Echo('All Tests Passed.')
  qa!
endfunction

function! s:Fail(err, ...)
  call Echo('Test Failed.')
  call Echo('')
  if type(a:err) == v:t_dict
    call Echo('Exception: ' .. string(get(a:err, 'exception', 'none')))
    call Echo('Throwpoint: ' .. string(get(a:err, 'throwpoint', 'none')))
  endif
  cq!
endfunction


" run

silent! call coquille#test#runTest()
      \.then(function('s:EditAndWait'))
      \.then(function('s:Succeed'))
      \.catch(function('s:Fail'))

