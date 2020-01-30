
let s:start = function('coquille#util#argsetup')
let s:get = function('coquille#util#argget')
let s:end = function('coquille#util#argend')

let s:getters = {}

function! s:config(name, ...) abort
  call s:start(a:000)
  let l:default = s:get(v:null)
  let l:candidates = s:get(0)
  let l:no_define_default = s:get(0)
  let l:scopes = s:get(['b', 'g'])
  call s:end()

  if !l:no_define_default
    if !exists('g:coquille_' .. a:name)
      let g:['coquille_' .. a:name] = l:default
    endif
  endif

  let s:getters[a:name] = {}

  function! s:getters[a:name].get(...) abort closure
    call s:start(a:000)
    let l:default2 = s:get(v:null)
    call s:end()

    for scope in l:scopes
      if exists(scope .. ':coquille_' .. a:name)
        return eval(scope .. ':coquille_' .. a:name)
      endif
    endfor
    if l:default2 isnot v:null
      return l:default2
    endif
    return l:default
  endfunction
endfunction

function coquille#options#get(name, ...)
  if a:0
    return s:getters[a:name].get(a:1)
  else
    return s:getters[a:name].get()
  endif
endfunction


call s:config('coq_executable', v:null, 1)

call s:config('auto_move', 0)
call s:config('cursor_ceiling', 1)
call s:config('show_goal_always', 0)
call s:config('update_status_always', 1)

call s:config('no_define_commands', 0)
call s:config('one_window', 0, 0, 0, ['t', 'g'])
call s:config('auto_launch', 1)
call s:config('auto_launch_args')

call s:config('highlight', 1)
call s:config('highlight_style_queued', 'all', ['all', 'tail', 'end_of_all'])
call s:config('highlight_style_checked', 'all', ['all', 'tail', 'end_of_all'])

call s:config('keep_after_textchange', 0)

call s:config('refresh_after_focus', 0)
call s:config('rerun_after_focus', 0)

call s:config('silent', 0)


" g:coquille#options#get({config name})
" g:coquille#options#get({config name}, default value)


