let s:current_dir=expand("<sfile>:p:h") 

if !exists('g:coquille_auto_move')
    let g:coquille_auto_move = 0
endif

function! coquille#resetPanels()
  if exists("b:goal_buf") && buffer_name(b:goal_buf) == "Goals"
    silent! execute 'bdelete' . s:goal_buf
  endif

  if exists("b:info_buf") && buffer_name(b:info_buf) == "Infos"
    silent! execute 'bdelete' . s:info_buf
  endif

  let l:winnr = winnr()
  rightbelow vnew Goals
    setlocal buftype=nofile
    setlocal filetype=coq-goals
    setlocal noswapfile
    let b:goal_buf = bufnr("%")
  rightbelow new Infos
    setlocal buftype=nofile
    setlocal filetype=coq-infos
    setlocal noswapfile
    let b:info_buf = bufnr("%")
  execute l:winnr . 'winc w'
endfunction

function! coquille#killSession()
    execute 'bdelete' . s:goal_buf
    execute 'bdelete' . s:info_buf
    py3 coquille.kill_coqtop()

    setlocal ei=InsertEnter
endfunction

function! coquille#rawQuery(...)
  " TODO
  " py3 coquille.coq_raw_query(*vim.eval("a:000"))
endfunction

function! coquille#FNMapping()
    "" --- Function keys bindings
    "" Works under all tested config.
    map <buffer> <silent> <F2> :CoqUndo<CR>
    map <buffer> <silent> <F3> :CoqNext<CR>
    map <buffer> <silent> <F4> :CoqToCursor<CR>

    imap <buffer> <silent> <F2> <C-\><C-o>:CoqUndo<CR>
    imap <buffer> <silent> <F3> <C-\><C-o>:CoqNext<CR>
    imap <buffer> <silent> <F4> <C-\><C-o>:CoqToCursor<CR>
endfunction

function! coquille#CoqideMapping()
    "" ---  CoqIde key bindings
    "" Unreliable: doesn't work with all terminals, doesn't work through tmux,
    ""  etc.
    map <buffer> <silent> <C-A-Up>    :CoqUndo<CR>
    map <buffer> <silent> <C-A-Left>  :CoqToCursor<CR>
    map <buffer> <silent> <C-A-Down>  :CoqNext<CR>
    map <buffer> <silent> <C-A-Right> :CoqToCursor<CR>

    imap <buffer> <silent> <C-A-Up>    <C-\><C-o>:CoqUndo<CR>
    imap <buffer> <silent> <C-A-Left>  <C-\><C-o>:CoqToCursor<CR>
    imap <buffer> <silent> <C-A-Down>  <C-\><C-o>:CoqNext<CR>
    imap <buffer> <silent> <C-A-Right> <C-\><C-o>:CoqToCursor<CR>
endfunction


" restart coquille IDE
function! coquille#launch(...)
  if exists("b:coquille#IDE")
    silent! call b:coquille#IDE.kill()
  endif

  let b:coquille#IDE = coquille#ide#makeInstance(a:000)
  let b:coquille_running = 1

  " make the different commands accessible
  " command! -buffer GotoDot py3 coquille.goto_last_sent_dot()
  " command! -buffer CoqNext py3 coquille.coq_next()
  " command! -buffer CoqUndo py3 coquille.coq_rewind()
  " command! -buffer CoqToCursor py3 coquille.coq_to_cursor()
  command! -buffer CoqRearrange call coquille#resetPanels()
  command! -buffer CoqKill call coquille#killSession()

  " command! -buffer -nargs=* Coq call coquille#rawQuery(<f-args>)

  call coquille#resetPanels()

  " au InsertEnter <buffer> py3 coquille.sync()
endfunction


" recognize this buffer as coq
function! coquille#register()
  " TODO : add auto-launch optoin

  hi default CheckedByCoq ctermbg=17 guibg=LightGreen
  hi default SentToCoq ctermbg=60 guibg=LimeGreen
  hi link CoqError Error

  let b:checked = -1
  let b:sent    = -1
  let b:errors  = -1

  command! -bar -buffer -nargs=* -complete=file CoqLaunch call coquille#launch(<f-args>)
endfunction
