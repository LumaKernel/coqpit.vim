let s:current_dir=expand("<sfile>:p:h") 

if !exists('g:coquille_auto_move')
    let g:coquille_auto_move = 0
endif

function! coquille#ResetPanels()
  " open the Goals & Infos panels before going back to the main window
  if exists("b:goal_buf") && buffer_name(b:goal_buf) == "Goals"
    execute b:goal_buf . 'winc w'
  endif

  if exists("b:info_buf") && buffer_name(b:info_buf) == "Infos"
    execute b:info_buf . 'winc w'
  endif

  let l:winnb = winnr()
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
  execute l:winnb . 'winc w'
endfunction

function! coquille#KillSession()
    execute 'bdelete' . s:goal_buf
    execute 'bdelete' . s:info_buf
    py3 coquille.kill_coqtop()

    setlocal ei=InsertEnter
endfunction

function! coquille#RawQuery(...)
    py3 coquille.coq_raw_query(*vim.eval("a:000"))
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

function! coquille#Launch(...)
  " initialize the plugin (launch coqtop)
  if exists("b:coquille_running")
    echo "Error: Coq is already running this buffer."
    return
  endif

  let b:coquille_id = bufnr("%")
  let b:coquille_running = 1

  py3 coquille.launch_coq(*vim.eval("map(copy(a:000),'expand(v:val)')"))

  " make the different commands accessible
  command! -buffer GotoDot py3 coquille.goto_last_sent_dot()
  command! -buffer CoqNext py3 coquille.coq_next()
  command! -buffer CoqUndo py3 coquille.coq_rewind()
  command! -buffer CoqToCursor py3 coquille.coq_to_cursor()
  command! -buffer CoqRearrange call coquille#ResetPanels()
  command! -buffer CoqKill call coquille#KillSession()

  command! -buffer -nargs=* Coq call coquille#RawQuery(<f-args>)

  call coquille#ResetPanels()

  " Automatically sync the buffer when entering insert mode: this is usefull
  " when we edit the portion of the buffer which has already been sent to coq,
  " we can then rewind to the appropriate point.
  " It's still incomplete though, the plugin won't sync when you undo or
  " delete some part of your buffer. So the highlighting will be wrong, but
  " nothing really problematic will happen, as sync will be called the next
  " time you explicitly call a command (be it 'rewind' or 'interp')
  au InsertEnter <buffer> py3 coquille.sync()
endfunction

function! coquille#Register()
    hi default CheckedByCoq ctermbg=17 guibg=LightGreen
    hi default SentToCoq ctermbg=60 guibg=LimeGreen
    hi link CoqError Error

    let b:checked = -1
    let b:sent    = -1
    let b:errors  = -1

    command! -bar -buffer -nargs=* -complete=file CoqLaunch call coquille#Launch(<f-args>)
endfunction
