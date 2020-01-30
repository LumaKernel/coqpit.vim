
" let s:start = function('coquille#util#argsetup')
" let s:get = function('coquille#util#argget')
" let s:end = function('coquille#util#argend')


" call s:start(a:000)
" let l:args = s:get([])
" call s:end()

function! coquille#util#argsetup(args) abort
  let s:args = a:args
  let s:index = 0
endfunction

function! coquille#util#argget(...) abort
  if a:0 > 1
    throw "[coquille.vim] At most one deafult value is accepted."
  endif
  let l:Ret = get(s:args, s:index, v:null)
  let s:index += 1
  if l:Ret is v:null
    return a:0 ? a:1 : v:null
  endif
  return l:Ret
endfunction

function! coquille#util#argend() abort
  if len(s:args) > s:index
    throw "[coquille.vim] Too many args."
  endif
  unlet s:args
  unlet s:index
endfunction

