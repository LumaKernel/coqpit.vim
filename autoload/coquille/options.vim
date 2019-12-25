
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

  let g:['coquille#options#' .. a:name] = l:getter
endfunction

call s:config('auto_move', 0)
call s:config('cursor_ceiling', 1)
call s:config('show_goal_always', 0)
call s:config('update_status_always', 1)

call s:config('no_define_commands', 0)
call s:config('one_window', 0)
call s:config('auto_launch', 1)
call s:config('auto_launch_args', [])

call s:config('no_open_windows', 0)

call s:config('silent', 0)


" g:coquille#options#{config name}.get()
" g:coquille#options#{config name}.get(default value)


