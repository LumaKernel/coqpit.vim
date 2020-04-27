" =========
" job shims
" =========
"
" The interface is like +job.
" Support neovim.

" NOTE : Some features are not supported and
"        some are specialized for coqpit.

let g:coqpit#job#supported = 0

if has('job')  " {{{1
  let g:coqpit#job#supported = 1

  function! coqpit#job#job_start(cmd, opt) abort
    let l:opt = {}
    if has_key(a:opt, 'out_cb')
      let l:opt.out_cb = {ch, data -> a:opt.out_cb(data)}
    endif
    if has_key(a:opt, 'err_cb')
      let l:opt.err_cb = {ch, data -> a:opt.err_cb(data)}
    endif
    if has_key(a:opt, 'exit_cb')
      let l:opt.exit_cb = {ch, data -> a:opt.exit_cb(data)}
    endif

    let l:opt.in_mode = 'raw'
    let l:opt.out_mode = 'raw'
    let l:opt.err_mode = 'raw'

    let l:opt.stoponexit = 'kill'

    return job_start(a:cmd, l:opt)
  endfunction

  function! coqpit#job#job_status(job) abort
    return job_status(a:job)
  endfunction

  function! coqpit#job#job_stop(job, ...) abort
    if a:0
      call job_stop(job)
    else
      call job_stop(job, a:1)
    endif
  endfunction

  function! coqpit#job#job_setoptions(job, opt) abort
    let l:opt = copy(a:opt)
    if has_key(opt, 'out_cb')
      let l:opt.out_cb = {ch, data -> a:opt.out_cb(data)}
    endif
    if has_key(opt, 'err_cb')
      let l:opt.err_cb = {ch, data -> a:opt.err_cb(data)}
    endif
    if has_key(opt, 'exit_cb')
      let l:opt.exit_cb = {ch, data -> a:opt.exit_cb(data)}
    endif

    call job_setoptions(a:job, l:opt)
  endfunction

  function! coqpit#job#ch_sendraw(job, raw) abort
    call ch_sendraw(a:job, a:raw)
  endfunction

elseif has('nvim')  " {{{1
  let g:coqpit#job#supported = 2

  function! coqpit#job#job_start(cmd, opt) abort
    let l:opt = {}
    let l:job = {
          \   'out_cb': get(a:opt, 'out_cb', {->0}),
          \   'err_cb': get(a:opt, 'err_cb', {->0}),
          \   'exit_cb': get(a:opt, 'exit_cb', {->0}),
          \ }
    let l:opt.on_stdout = {ch, data -> l:job.out_cb(data)}
    let l:opt.on_stderr = {ch, data -> l:job.err_cb(data)}
    function! l:opt.on_stdout(ch, data, name) abort closure
      if v:exiting isnot v:null | return | endif
      if len(a:data) == 1 && a:data[0] == '' | return | endif
      call l:job.out_cb(join(a:data, "\n"))
    endfunction
    function! l:opt.on_exit(ch, data, name) abort closure
      if v:exiting isnot v:null | return | endif
      if len(a:data) == 1 && a:data[0] == '' | return | endif
      call l:job.err_cb(join(a:data, "\n"))
    endfunction
    function! l:opt.on_exit(ch, data, name) abort closure
      if v:exiting isnot v:null | return | endif
      let l:job.status = 'dead'
      call l:job.exit_cb(a:data)
    endfunction

    let l:job.id = jobstart(a:cmd, l:opt)

    let l:job.status = 'run'
    if l:job.id == -1
      let l:job.status = 'fail'
    endif

    return l:job
  endfunction

  function! coqpit#job#job_status(job) abort
    return a:job.status
  endfunction

  function! coqpit#job#job_stop(job, ...) abort
    call jobstop(a:job.id)
  endfunction

  function! coqpit#job#job_setoptions(job, opt) abort
    if has_key(a:opt, 'out_cb')
      let l:job.out_cb = a:opt.out_cb
    endif
    if has_key(a:opt, 'err_cb')
      let l:job.err_cb = a:opt.err_cb
    endif
    if has_key(a:opt, 'exit_cb')
      let l:job.exit_cb = a:opt.exit_cb
    endif
  endfunction

  function! coqpit#job#ch_sendraw(job, raw) abort
    call chansend(a:job.id, a:raw)
  endfunction
else  " {{{1
  function! coqpit#job#job_start() abort
    throw 'Job features are not supported'
  endfunction
endif
