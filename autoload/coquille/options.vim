
function! s:config(name, default) abort
  if !exists('g:coquille_' .. a:name)
    let g:['coquille_' .. a:name] = a:default
  endif
  let l:getter = {}

  function! l:getter.get(default2 = v:none) abort closure
    if exists('b:coquille_' .. a:name)
      return b:['coquille_' .. a:name]
    endif
    if exists('g:coquille_' .. a:name)
      return g:['coquille_' .. a:name]
    endif
    if default2 isnot v:none
      return a:default2
    endif
    return a:default
  endfunction

  return l:getter
endfunction

let coquille#options#auto_move = s:config('auto_move', 0)
let coquille#options#cursor_ceiling = s:config('cursor_ceiling', 1)
let coquille#options#show_goal_always = s:config('show_goal_always', 0)
let coquille#options#update_status_always = s:config('update_status_always', 1)

