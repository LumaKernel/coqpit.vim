l ========
" coquille
" ========


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

" reset_pannels {{{
function! coquille#reset_panels(force = 0) abort
  if g:coquille#options#one_window.get()

    call coquille#init_tablocal_windows(a:force)
    
    call b:coquilleIDE.addGoalBuffer(t:goal_buf)
    call b:coquilleIDE.addInfoBuffer(t:info_buf)
    call b:coquilleIDE.refresh()
  else
    if !exists('b:coquilleIDE') | return | endif
    call coquille#init_buflocal_windows(1)

    call b:coquilleIDE.addGoalBuffer(b:goal_buf)
    call b:coquilleIDE.addInfoBuffer(b:info_buf)
    call b:coquilleIDE.refresh()
  endif
endfunction
" }}}

" ini_tablocal_windows {{{
function! coquille#init_tablocal_windows(force) abort
  if !exists('b:coquilleIDE') | return | endif

  if exists('t:goal_buf') && !bufexists(t:goal_buf) | silent! unlet t:goal_buf | endif
  if exists('t:info_buf') && !bufexists(t:info_buf) | silent! unlet t:info_buf | endif

  if !exists('t:goal_buf') || !exists('t:info_buf') || a:force
    if exists('t:goal_buf') | silent! execute 'bwipeout' .. t:goal_buf | endif
    if exists('t:info_buf') | silent! execute 'bwipeout' .. t:info_buf | endif
    silent! unlet t:goal_buf
    silent! unlet t:info_buf
  endif

  if exists('t:goal_buf') && exists('t:info_buf')
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
    let t:goal_buf = bufnr('%')
    call add(s:window_bufnrs, t:goal_buf)
  rightbelow new
    setlocal buftype=nofile
    call s:name_buffer_unique('Infos-shared')
    setlocal filetype=coq-infos
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let t:info_buf = bufnr('%')
    call add(s:window_bufnrs, t:info_buf)
  execute l:winnr .. 'winc w'
endfunction
" }}}

" init_buflocal_windows {{{
function! coquille#init_buflocal_windows(force) abort
  if !exists('b:coquilleIDE') | return | endif

  if exists('b:goal_buf') && !bufexists(b:goal_buf) | silent! unlet b:goal_buf | endif
  if exists('b:info_buf') && !bufexists(b:info_buf) | silent! unlet b:info_buf | endif

  if !exists('b:goal_buf') || !exists('b:info_buf') || a:force
    if exists('b:goal_buf') | silent! execute 'bwipeout' .. b:goal_buf | endif
    if exists('b:info_buf') | silent! execute 'bwipeout' .. b:info_buf | endif
    silent! unlet b:goal_buf
    silent! unlet b:info_buf
  endif

  if exists('b:goal_buf') && exists('b:info_buf')
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
    let l:goal_buf = bufnr('%')
    call add(s:window_bufnrs, l:goal_buf)
  rightbelow new
    setlocal buftype=nofile
    call s:name_buffer_unique('Infos:' .. fname)
    setlocal filetype=coq-infos
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let b:coquilleIDE = l:coquilleIDE
    call coquille#define_buffer_commands()
    let l:info_buf = bufnr('%')
    call add(s:window_bufnrs, l:info_buf)
  execute l:winnr .. 'winc w'
  
  let b:goal_buf = l:goal_buf
  let b:info_buf = l:info_buf
endfunction
" }}}

" stop {{{
function! coquille#stop()
  if !exists('b:coquilleIDE') | return | endif

  if !g:coquille#options#one_window.get()
    if exists('b:goal_buf') | silent! execute 'bwipeout' .. b:goal_buf | endif
    if exists('b:info_buf') | silent! execute 'bwipeout' .. b:info_buf | endif
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

" define commands {{{
function! coquille#define_buffer_commands(force = 0)
  if !a:force && g:coquille#options#no_define_commands.get()
    return
  endif
  command! -bar -buffer -nargs=* -complete=file CoqLaunch call coquille#launch([<f-args>])
  command! -buffer CoqNext call coquille#check_running() | call b:coquilleIDE.coq_next()
  command! -buffer CoqBack call coquille#check_running() | call b:coquilleIDE.coq_back()
  command! -buffer CoqToCursor call coquille#check_running() | call b:coquilleIDE.coq_to_cursor()
  command! -buffer CoqToLast call coquille#check_running() | call b:coquilleIDE.coq_to_last()
  command! -buffer CoqRerun call coquille#check_running() | call b:coquilleIDE.rerun()
  command! -buffer CoqRefresh call coquille#check_running() | call b:coquilleIDE.refresh()
  command! -buffer CoqStop call coquille#check_running() | call coquille#stop()
  command! -buffer MoveToTop call coquille#check_running() | call b:coquilleIDE.move_to_top()
  command! -buffer -nargs=* CoqQuery call coquille#check_running() | call b:coquilleIDE.query(<q-args>)
  command! -buffer CoqClear call coquille#check_running() | call b:coquileIDE.clear_info()
endfunction

function! coquille#define_global_commands(force = 0)
  if !a:force && g:coquille#options#no_define_commands.get()
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

