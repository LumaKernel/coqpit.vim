" ========
" coqpit
" ========

let s:start = function('coqpit#util#argsetup')
let s:get = function('coqpit#util#argget')
let s:end = function('coqpit#util#argend')


let coqpit#repository_url = 'https://github.com/LumaKernel/coqpit'

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
function! coqpit#reset_panels(...) abort
  call s:start(a:000)
  let l:force = s:get(0)
  call s:end()

  if g:coqpit#options#get('one_window')

    call coqpit#init_tablocal_windows(l:force)

    call b:coqpitIDE.addGoalBuffer(t:coqpit_goal_bufnr)
    call b:coqpitIDE.addInfoBuffer(t:coqpit_info_bufnr)
    call b:coqpitIDE.refresh()
  else
    if !exists('b:coqpitIDE') | return | endif
    call coqpit#init_buflocal_windows(1)

    call b:coqpitIDE.addGoalBuffer(b:coqpit_goal_bufnr)
    call b:coqpitIDE.addInfoBuffer(b:coqpit_info_bufnr)
    call b:coqpitIDE.refresh()
  endif
endfunction
" }}}

" ini_tablocal_windows() {{{
function! coqpit#init_tablocal_windows(force) abort
  if !exists('b:coqpitIDE') | return | endif

  if exists('t:coqpit_goal_bufnr') && !bufexists(t:coqpit_goal_bufnr) | silent! unlet t:coqpit_goal_bufnr | endif
  if exists('t:coqpit_info_bufnr') && !bufexists(t:coqpit_info_bufnr) | silent! unlet t:coqpit_info_bufnr | endif

  if !exists('t:coqpit_goal_bufnr') || !exists('t:coqpit_info_bufnr') || a:force
    if exists('t:coqpit_goal_bufnr') | silent! execute 'bwipeout' .. t:coqpit_goal_bufnr | endif
    if exists('t:coqpit_info_bufnr') | silent! execute 'bwipeout' .. t:coqpit_info_bufnr | endif
    silent! unlet t:coqpit_goal_bufnr
    silent! unlet t:coqpit_info_bufnr
  endif

  if exists('t:coqpit_goal_bufnr') && exists('t:coqpit_info_bufnr')
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
    let t:coqpit_goal_bufnr = bufnr('%')
    call add(s:window_bufnrs, t:coqpit_goal_bufnr)
  rightbelow new
    setlocal buftype=nofile
    call s:name_buffer_unique('Infos-shared')
    setlocal filetype=coq-infos
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let t:coqpit_info_bufnr = bufnr('%')
    call add(s:window_bufnrs, t:coqpit_info_bufnr)
  execute l:winnr .. 'winc w'
endfunction
" }}}

" init_buflocal_windows() {{{
function! coqpit#init_buflocal_windows(force) abort
  if !exists('b:coqpitIDE') | return | endif

  if exists('b:coqpit_goal_bufnr') && !bufexists(b:coqpit_goal_bufnr) | silent! unlet b:coqpit_goal_bufnr | endif
  if exists('b:coqpit_info_bufnr') && !bufexists(b:coqpit_info_bufnr) | silent! unlet b:coqpit_info_bufnr | endif

  if !exists('b:coqpit_goal_bufnr') || !exists('b:coqpit_info_bufnr') || a:force
    if exists('b:coqpit_goal_bufnr') | silent! execute 'bwipeout' .. b:coqpit_goal_bufnr | endif
    if exists('b:coqpit_info_bufnr') | silent! execute 'bwipeout' .. b:coqpit_info_bufnr | endif
    silent! unlet b:coqpit_goal_bufnr
    silent! unlet b:coqpit_info_bufnr
  endif

  if exists('b:coqpit_goal_bufnr') && exists('b:coqpit_info_bufnr')
    return
  endif

  let l:coqpitIDE = b:coqpitIDE

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
    let b:coqpitIDE = l:coqpitIDE
    call coqpit#define_buffer_commands()
    let l:coqpit_goal_bufnr = bufnr('%')
    call add(s:window_bufnrs, l:coqpit_goal_bufnr)
  rightbelow new
    setlocal buftype=nofile
    call s:name_buffer_unique('Infos:' .. fname)
    setlocal filetype=coq-infos
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let b:coqpitIDE = l:coqpitIDE
    call coqpit#define_buffer_commands()
    let l:coqpit_info_bufnr = bufnr('%')
    call add(s:window_bufnrs, l:coqpit_info_bufnr)
  execute l:winnr .. 'winc w'

  for bufnr in [l:coqpit_goal_bufnr, l:coqpit_info_bufnr]
    call setbufvar(bufnr, 'coqpit_goal_bufnr', l:coqpit_goal_bufnr)
    call setbufvar(bufnr, 'coqpit_info_bufnr', l:coqpit_info_bufnr)
  endfor
  let b:coqpit_goal_bufnr = l:coqpit_goal_bufnr
  let b:coqpit_info_bufnr = l:coqpit_info_bufnr
endfunction
" }}}

" stop {{{
function! coqpit#stop()
  if !exists('b:coqpitIDE') | return | endif

  if !g:coqpit#options#get('one_window')
    if exists('b:coqpit_goal_bufnr') | silent! execute 'bwipeout' .. b:coqpit_goal_bufnr | endif
    if exists('b:coqpit_info_bufnr') | silent! execute 'bwipeout' .. b:coqpit_info_bufnr | endif
  endif

  if exists('b:coqpitIDE')
    call b:coqpitIDE.kill()
  endif
endfunction
" }}}

" stop_all {{{
function! coqpit#stop_all()
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

function! coqpit#query(query_str)
  if !exists('b:coqpitIDE') | return | endif

  call b:coqpitIDE.query(a:query_str)
endfunction

" coqpit#define_buffer_commands(force = 0) < define commands > {{{
function! coqpit#define_buffer_commands(...)
  call s:start(a:000)
  let l:force = s:get(0)
  call s:end()

  if !l:force && g:coqpit#options#get('no_define_commands')
    return
  endif
  command! -bar -buffer -nargs=* -complete=file CoqLaunch call coqpit#launch([<f-args>])
  command! -buffer CoqNext call coqpit#check_running() | call b:coqpitIDE.coq_next()
  command! -buffer CoqBack call coqpit#check_running() | call b:coqpitIDE.coq_back()
  command! -buffer CoqToCursor call coqpit#check_running() | call b:coqpitIDE.coq_to_cursor()
  command! -buffer CoqToLast call coqpit#check_running() | call b:coqpitIDE.coq_to_last()
  command! -buffer CoqRerun call coqpit#check_running() | call b:coqpitIDE.rerun()
  command! -buffer CoqRefresh call coqpit#check_running() | call b:coqpitIDE.refresh()
  command! -buffer CoqRecolor call coqpit#check_running() | call b:coqpitIDE.recolor()
  command! -buffer CoqSwitchHighlight call coqpit#switch_highlight()
  command! -buffer CoqStop call coqpit#stop()
  command! -buffer MoveToTop call coqpit#check_running() | call b:coqpitIDE.move_to_top()
  command! -buffer -nargs=* CoqQuery call coqpit#check_running() | call b:coqpitIDE.query(<q-args>)
  command! -buffer CoqClear call coqpit#check_running() | call b:coqpitIDE.clear_info()
endfunction

function! coqpit#define_global_commands(...)
  call s:start(a:000)
  let l:force = s:get(0)
  call s:end()

  if !l:force && g:coqpit#options#get('no_define_commands')
    return
  endif
  command! CoqStopAll call coqpit#stop_all()
  command! CoqRearrange call coqpit#reset_panels(1)
endfunction

" }}}

function! coqpit#check_running() abort
  try
    if !exists('b:coqpitIDE') || b:coqpitIDE.dead()
      throw ''
    endif
  catch /.*/
    echoerr '[coqpit.vim] coqpitIDE is not running. Please try to run :CoqLaunch or :call coqpit#launch() to start.'
  endtry
endfunction

" delete_commands {{{
function! coqpit#delete_commands()
  silent! delc CoqNext
  silent! delc CoqBack
  silent! delc CoqToCursor
  silent! delc CoqToLast
  silent! delc CoqRerun
  silent! delc CoqRefresh
  silent! delc CoqRecolor
  silent! delc CoqStop
  silent! delc CoqSwitchHighlight
  silent! delc MoveToTop
  silent! delc CoqQuery
endfunction
" }}}

" restart coqpit IDE
function! coqpit#launch(args)
  if exists('b:coqpitIDE')
    silent! call b:coqpitIDE.kill()
  endif

  let b:coqpitIDE = coqpit#IDE#new(bufnr('%'), a:args)
  call add(s:IDE_instances, b:coqpitIDE)

  call coqpit#define_global_commands()
  call coqpit#define_buffer_commands()

  call coqpit#reset_panels()
endfunction

function! coqpit#switch_highlight() abort
  if !exists('b:coqpitIDE') || b:coqpitIDE.dead()
    return
  endif

  let b:coqpitIDE.highlight = !b:coqpitIDE.highlight
  call b:coqpitIDE.recolor()
endfunction


" recognize this buffer as coq
" NOTE : the buffer's filetype can be not coq
function! coqpit#register()
  if g:coqpit#options#get('auto_launch') isnot 0
    let args = g:coqpit#options#get('auto_launch_args')
    call coqpit#launch(args)
  endif

  if !g:coqpit#options#get('no_define_commands')
    command! -bar -buffer -nargs=* -complete=file CoqLaunch call coqpit#launch([<f-args>])
  endif
endfunction

function! coqpit#coq_version() abort
  if !exists('b:coqpitIDE')
    throw '[coqpit.vim] Coqpit.vim is not running in current buffer.'
  endif

  return b:coqpitIDE.coqtop_handler.coq_version
endfunction

function! coqpit#version()
  return '3.0.0'
endfunction
