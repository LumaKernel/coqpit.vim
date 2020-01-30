" ========
" coquille
" ========

let s:start = function('coquille#util#argsetup')
let s:get = function('coquille#util#argget')
let s:end = function('coquille#util#argend')


let coquille#repository_url = 'https://github.com/LumaKernel/coquille'

" For strong reset, stop all, endure dynamic option changing
let s:window_bufnrs = []
let s:IDE_instances = []

let s:num = 0

function! s:name_buffer_unique(name) abort
  if !bufexists('[' .. a:name .. ']')
    silent exe 'file [' .. a:name .. ']'
    return
  endif

  while bufexists('[' .. a:name .. '_' .. s:num .. ']')
    let s:num += 1
  endwhile
  silent exe 'file [' .. a:name .. '_' .. s:num .. ']'
endfunction

" reset_pannels(force = 0) {{{
function! coquille#reset_panels(...) abort
  call s:start(a:000)
  let l:force = s:get(0)
  call s:end()

  if g:coquille#options#one_window.get()

    call coquille#init_tablocal_windows(l:force)
    
    call b:coquilleIDE.addGoalBuffer(t:coquille_goal_bufnr)
    call b:coquilleIDE.addInfoBuffer(t:coquille_info_bufnr)
    call b:coquilleIDE.refresh()
  else
    if !exists('b:coquilleIDE') | return | endif
    call coquille#init_buflocal_windows(1)

    call b:coquilleIDE.addGoalBuffer(b:coquille_goal_bufnr)
    call b:coquilleIDE.addInfoBuffer(b:coquille_info_bufnr)
    call b:coquilleIDE.refresh()
  endif
endfunction
" }}}

" ini_tablocal_windows() {{{
function! coquille#init_tablocal_windows(force) abort
  if !exists('b:coquilleIDE') | return | endif

  if exists('t:coquille_goal_bufnr') && !bufexists(t:coquille_goal_bufnr) | silent! unlet t:coquille_goal_bufnr | endif
  if exists('t:coquille_info_bufnr') && !bufexists(t:coquille_info_bufnr) | silent! unlet t:coquille_info_bufnr | endif

  if !exists('t:coquille_goal_bufnr') || !exists('t:coquille_info_bufnr') || a:force
    if exists('t:coquille_goal_bufnr') | silent! execute 'bwipeout' .. t:coquille_goal_bufnr | endif
    if exists('t:coquille_info_bufnr') | silent! execute 'bwipeout' .. t:coquille_info_bufnr | endif
    silent! unlet t:coquille_goal_bufnr
    silent! unlet t:coquille_info_bufnr
  endif

  if exists('t:coquille_goal_bufnr') && exists('t:coquille_info_bufnr')
    return
  endif

  let l:winnr = winnr()
  botright vnew
    setlocal buftype=nofile
    call s:name_buffer_unique('Goals-shared')
    setlocal filetype=coq-goals
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let t:coquille_goal_bufnr = bufnr('%')
    call add(s:window_bufnrs, t:coquille_goal_bufnr)
  rightbelow new
    setlocal buftype=nofile
    call s:name_buffer_unique('Infos-shared')
    setlocal filetype=coq-infos
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let t:coquille_info_bufnr = bufnr('%')
    call add(s:window_bufnrs, t:coquille_info_bufnr)
  execute l:winnr .. 'winc w'
endfunction
" }}}

" init_buflocal_windows() {{{
function! coquille#init_buflocal_windows(force) abort
  if !exists('b:coquilleIDE') | return | endif

  if exists('b:coquille_goal_bufnr') && !bufexists(b:coquille_goal_bufnr) | silent! unlet b:coquille_goal_bufnr | endif
  if exists('b:coquille_info_bufnr') && !bufexists(b:coquille_info_bufnr) | silent! unlet b:coquille_info_bufnr | endif

  if !exists('b:coquille_goal_bufnr') || !exists('b:coquille_info_bufnr') || a:force
    if exists('b:coquille_goal_bufnr') | silent! execute 'bwipeout' .. b:coquille_goal_bufnr | endif
    if exists('b:coquille_info_bufnr') | silent! execute 'bwipeout' .. b:coquille_info_bufnr | endif
    silent! unlet b:coquille_goal_bufnr
    silent! unlet b:coquille_info_bufnr
  endif

  if exists('b:coquille_goal_bufnr') && exists('b:coquille_info_bufnr')
    return
  endif

  let l:coquilleIDE = b:coquilleIDE

  let fname = expand('%:t:r')
  let l:winnr = winnr()

  rightbelow vnew
    setlocal buftype=nofile
    call s:name_buffer_unique('Goals:' .. fname)
    setlocal filetype=coq-goals
    setlocal filetype=coq-goals
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let b:coquilleIDE = l:coquilleIDE
    call coquille#define_buffer_commands()
    let l:coquille_goal_bufnr = bufnr('%')
    call add(s:window_bufnrs, l:coquille_goal_bufnr)
  rightbelow new
    setlocal buftype=nofile
    call s:name_buffer_unique('Infos:' .. fname)
    setlocal filetype=coq-infos
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let b:coquilleIDE = l:coquilleIDE
    call coquille#define_buffer_commands()
    let l:coquille_info_bufnr = bufnr('%')
    call add(s:window_bufnrs, l:coquille_info_bufnr)
  execute l:winnr .. 'winc w'
  
  for bufnr in [l:coquille_goal_bufnr, l:coquille_info_bufnr]
    call setbufvar(bufnr, 'coquille_goal_bufnr', l:coquille_goal_bufnr)
    call setbufvar(bufnr, 'coquille_info_bufnr', l:coquille_info_bufnr)
  endfor
  let b:coquille_goal_bufnr = l:coquille_goal_bufnr
  let b:coquille_info_bufnr = l:coquille_info_bufnr
endfunction
" }}}

" stop {{{
function! coquille#stop()
  if !exists('b:coquilleIDE') | return | endif

  if !g:coquille#options#one_window.get()
    if exists('b:coquille_goal_bufnr') | silent! execute 'bwipeout' .. b:coquille_goal_bufnr | endif
    if exists('b:coquille_info_bufnr') | silent! execute 'bwipeout' .. b:coquille_info_bufnr | endif
  endif

  if exists('b:coquilleIDE')
    call b:coquilleIDE.kill()
  endif
endfunction
" }}}

" stop_all {{{
function! coquille#stop_all()
  for IDE in s:IDE_instances
    silent! call IDE.kill()
  endfor

  for bufnr in s:window_bufnrs
    if bufexists(bufnr)
      silent! execute 'bwipeout' .. bufnr
    endif
  endfor

  let s:window_bufnrs = []
  let s:IDE_instances = []
endfunction
" }}}

function! coquille#query(query_str)
  if !exists('b:coquilleIDE') | return | endif

  call (a:query_str)
endfunction

" coquille#define_buffer_commands(force = 0) < define commands > {{{
function! coquille#define_buffer_commands(...)
  call s:start(a:000)
  let l:force = s:get(0)
  call s:end()

  if !l:force && g:coquille#options#no_define_commands.get()
    return
  endif
  command! -bar -buffer -nargs=* -complete=file CoqLaunch call coquille#launch([<f-args>])
  command! -buffer CoqNext call coquille#check_running() | call b:coquilleIDE.coq_next()
  command! -buffer CoqBack call coquille#check_running() | call b:coquilleIDE.coq_back()
  command! -buffer CoqToCursor call coquille#check_running() | call b:coquilleIDE.coq_to_cursor()
  command! -buffer CoqToLast call coquille#check_running() | call b:coquilleIDE.coq_to_last()
  command! -buffer CoqRerun call coquille#check_running() | call b:coquilleIDE.rerun()
  command! -buffer CoqRefresh call coquille#check_running() | call b:coquilleIDE.refresh()
  command! -buffer CoqStop call coquille#stop()
  command! -buffer MoveToTop call coquille#check_running() | call b:coquilleIDE.move_to_top()
  command! -buffer -nargs=* CoqQuery call coquille#check_running() | call b:coquilleIDE.query(<q-args>)
  command! -buffer CoqClear call coquille#check_running() | call b:coquilleIDE.clear_info()
endfunction

function! coquille#define_global_commands(...)
  call s:start(a:000)
  let l:force = s:get(0)
  call s:end()

  if !l:force && g:coquille#options#no_define_commands.get()
    return
  endif
  command! CoqStopAll call coquille#stop_all()
  command! CoqRearrange call coquille#reset_panels(1)
endfunction

" }}}

function! coquille#check_running() abort
  try
    if !exists('b:coquilleIDE') || b:coquilleIDE.dead()
      throw ''
    endif
  catch /.*/
    echoerr '[coquille.vim] CoquilleIDE is not running. Please try to run :CoqLaunch or :call coquille#launch() to start.'
  endtry
endfunction

" delete_commands {{{
function! coquille#delete_commands()
  silent! delc CoqNext
  silent! delc CoqBack
  silent! delc CoqToCursor
  silent! delc CoqToLast
  silent! delc CoqRerun
  silent! delc CoqRefresh
  silent! delc CoqStop
  silent! delc MoveToTop
  silent! delc CoqQuery
endfunction!
" }}}

" restart coquille IDE
function! coquille#launch(args)
  if exists('b:coquilleIDE')
    silent! call b:coquilleIDE.kill()
  endif

  let b:coquilleIDE = coquille#IDE#new(bufnr('%'), a:args)
  call add(s:IDE_instances, b:coquilleIDE)

  call coquille#define_global_commands()
  call coquille#define_buffer_commands()

  call coquille#reset_panels()
endfunction

" recognize this buffer as coq
" NOTE : the buffer's filetype can be not coq
function! coquille#register()
  if g:coquille#options#auto_launch.get() isnot 0
    let args = g:coquille#options#auto_launch_args.get()
    call coquille#launch(args)
  endif

  if !g:coquille#options#no_define_commands.get()
    command! -bar -buffer -nargs=* -complete=file CoqLaunch call coquille#launch([<f-args>])
  endif
endfunction

