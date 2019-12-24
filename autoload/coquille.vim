" ========
" coquille
" ========


let coquille#repository_url = 'https://github.com/LumaKernel/coquille'


let s:current_dir=expand('<sfile>:p:h')

function! coquille#reset_panels() abort
  if exists('b:goal_buf') && buffer_name(b:goal_buf) ==# 'Goals'
    silent! execute 'bdelete' .. b:goal_buf
  endif

  if exists('b:info_buf') && buffer_name(b:info_buf) ==# 'Infos'
    silent! execute 'bdelete' .. b:info_buf
  endif

  let l:winnr = winnr()
  rightbelow vnew Goals
    setlocal buftype=nofile
    setlocal filetype=coq-goals
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let l:goal_buf = bufnr('%')
  rightbelow new Infos
    setlocal buftype=nofile
    setlocal filetype=coq-infos
    setlocal noswapfile
    setlocal nocursorline
    setlocal nocursorcolumn
    let l:info_buf = bufnr('%')
  execute l:winnr .. 'winc w'
  
  let b:goal_buf = l:goal_buf
  let b:info_buf = l:info_buf
  call b:coquilleIDE.addGoalBuffer(b:goal_buf)
  call b:coquilleIDE.addInfoBuffer(b:info_buf)
endfunction

function! coquille#killSession()
    execute 'bdelete' .. b:goal_buf
    execute 'bdelete' .. b:info_buf
    " py3 coquille.kill_coqtop()

    setlocal eventignore=InsertEnter
endfunction

function! coquille#rawQuery(...)
  " TODO
  " py3 coquille.coq_raw_query(*vim.eval("a:000"))
endfunction

function! coquille#FNMapping()
    "" --- Function keys bindings
    "" Works under all tested config.
    map <buffer> <silent> <F2> :coqBack<CR>
    map <buffer> <silent> <F3> :CoqNext<CR>
    map <buffer> <silent> <F4> :CoqToCursor<CR>

    imap <buffer> <silent> <F2> <C-\><C-o>:coqBack<CR>
    imap <buffer> <silent> <F3> <C-\><C-o>:CoqNext<CR>
    imap <buffer> <silent> <F4> <C-\><C-o>:CoqToCursor<CR>
endfunction

function! coquille#CoqideMapping()
    "" ---  CoqIde key bindings
    "" Unreliable: doesn't work with all terminals, doesn't work through tmux,
    ""  etc.
    map <buffer> <silent> <C-A-Up>    :coqBack<CR>
    map <buffer> <silent> <C-A-Left>  :CoqToCursor<CR>
    map <buffer> <silent> <C-A-Down>  :CoqNext<CR>
    map <buffer> <silent> <C-A-Right> :CoqToCursor<CR>

    imap <buffer> <silent> <C-A-Up>    <C-\><C-o>:coqBack<CR>
    imap <buffer> <silent> <C-A-Left>  <C-\><C-o>:CoqToCursor<CR>
    imap <buffer> <silent> <C-A-Down>  <C-\><C-o>:CoqNext<CR>
    imap <buffer> <silent> <C-A-Right> <C-\><C-o>:CoqToCursor<CR>
endfunction


" restart coquille IDE
function! coquille#launch(...)
  if exists('b:coquille#IDE')
    silent! call b:coquilleIDE.kill()
  endif

  let b:coquilleIDE = coquille#IDE#new(bufnr('%'), a:000)
  let b:coquille_running = 1

  " make the different commands accessible
  " command! -buffer GotoDot py3 coquille.goto_last_sent_dot()
  command! -buffer CoqNext call b:coquilleIDE.coq_next()
  command! -buffer CoqBack call b:coquilleIDE.coq_back()
  command! -buffer CoqToCursor call b:coquilleIDE.coq_to_cursor()
  command! -buffer CoqToLast call b:coquilleIDE.coq_to_last()
  command! -buffer CoqRerun call b:coquilleIDE.rerun()
  command! -buffer CoqRearrange call coquille#reset_panels()
  command! -buffer CoqKill call coquille#killSession()
  command! -buffer MoveToTop call b:coquilleIDE.move_to_top()

  " command! -buffer -nargs=* Coq call coquille#rawQuery(<f-args>)

  call coquille#reset_panels()

  " au InsertEnter <buffer> py3 coquille.sync()
endfunction


" recognize this buffer as coq
function! coquille#register()
  " TODO : add auto-launch optoin

  augroup cs
    autocmd!
    autocmd ColorScheme * :call coquille#color#defineColorScheme()
  augroup END

  command! -bar -buffer -nargs=* -complete=file CoqLaunch call coquille#launch(<f-args>)
endfunction

