
" let s:start = function('coqpit#util#argsetup')
" let s:get = function('coqpit#util#argget')
" let s:end = function('coqpit#util#argend')


" call s:start(a:000)
" let l:args = s:get([])
" call s:end()

function! coqpit#util#argsetup(args) abort
  let s:args = a:args
  let s:index = 0
endfunction

function! coqpit#util#argget(...) abort
  if a:0 > 1
    throw "[coqpit.vim] At most one deafult value is accepted."
  endif
  let l:Ret = get(s:args, s:index, v:null)
  let s:index += 1
  if l:Ret is v:null
    return a:0 ? a:1 : v:null
  endif
  return l:Ret
endfunction

function! coqpit#util#argend() abort
  if len(s:args) > s:index
    throw "[coqpit.vim] Too many args."
  endif
  unlet s:args
  unlet s:index
endfunction
