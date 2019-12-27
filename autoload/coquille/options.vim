
function! s:config(name, default = v:null, no_define_default = 0, scopes = ['b', 'g']) abort
  if !a:no_define_default
    if !exists('g:coquille_' .. a:name)
      let g:['coquille_' .. a:name] = a:default
    endif
  endif

  let l:getter = {}

  function! l:getter.get(default2 = v:null) abort closure
    for scope in a:scopes
      if exists(scope .. ':coquille_' .. a:name)
        return eval(scope .. ':coquille_' .. a:name)
      endif
    endfor
    if default2 isnot v:null
      return a:default2
    endif
    return a:default
  endfunction

  let g:['coquille#options#' .. a:name] = l:getter
endfunction

call s:config('coq_executable', v:none, 1)

call s:config('auto_move', 0)
call s:config('cursor_ceiling', 1)
call s:config('show_goal_always', 0)
call s:config('update_status_always', 1)

call s:config('no_define_commands', 0)
call s:config('one_window', 0, v:none, ['t', 'g'])
call s:config('auto_launch', 1)
call s:config('auto_launch_args', [])

call s:config('keep_after_textchange', 0)

call s:config('refresh_after_focus', 0)
call s:config('rerun_after_focus', 0)

call s:config('silent', 0)


" g:coquille#options#{config name}.get()
" g:coquille#options#{config name}.get(default value)


