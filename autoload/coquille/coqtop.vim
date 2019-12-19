let s:to_check_default = [
    \ [
      \ 'coqidetop',
      \ '-main-channel',
      \ 'stdfds',
      \ '-async-proofs',
      \ 'on'
    \ ],
    \ [
      \ 'coqtop',
      \ '-ideslave',
      \ '-main-channel',
      \ 'stdfds',
      \ '-async-proofs',
      \ 'on'
    \ ]
  \ ]

" if config exists, use only that
" if that is list, use as it is
" if that is string, automatically select options
function! coquille#coqtop#get_executable(callback) abort
  let to_check = deepcopy(s:to_check_default)

  for scope in ['b', 'g']
    if exists(scope .. ':coquille_coq_executable')
      let val = eval(scope .. ':coquille_coq_executable')
      if type(val) == v:t_list
        call a:callback(val)
        return
      elseif type(val) == v:t_string
        let to_check[0][0] = val
        let to_check[1][0] = val
        break
      endif
    endif
  endfor

  let checker = {}
  let checker.done = {}

  function! checker.make_cb(i) abort closure
    function! self.cb(ok) abort closure
      if get(self.done, a:i, 0)
        return
      endif
      let self.done[a:i] = 1
      if a:ok
        call a:callback(to_check[a:i], a:ok)
      else
        call self.check(a:i + 1)
      endif
    endfunction

    return self.cb
  endfunction

  function! checker.check(i) abort closure
    if a:i >= len(to_check)
      call a:callback(v:null, '')
      return
    endif
    call s:is_executable(to_check[a:i], self.make_cb(a:i))
  endfunction
  call checker.check(0)
endfunction


" not only once calling back
" use first of them
function! s:is_executable(cmd, callback) abort
  let job_options = {}
  let err = 0

  function! job_options.out_cb(ch, msg) abort closure
    let xml = webapi#xml#parse(a:msg)
    if xml.name !=# 'value' | return | endif
    if get(xml.attr, 'val') !=# 'good' | return a:callback(0) | endif
    let coq_info = xml.find('coq_info')
    if empty(coq_info) | return a:callback(0) | endif
    if !len(coq_info.child) | return a:callback(0) | endif
    call a:callback(coquille#xml#2str(coq_info.child[0]))
  endfunction

  function! job_options.err_cb(ch, msg) abort closure
    call a:callback(0)
  endfunction

  function! job_options.exit_cb(ch, exit_status) abort closure
    call a:callback(0)
  endfunction

  let job_options.in_mode = 'raw'
  let job_options.out_mode = 'raw'
  let job_options.err_mode = 'nl'
  let job_options.out_cb = function(job_options.out_cb, job_options)
  let job_options.err_cb = function(job_options.err_cb, job_options)
  let job_options.exit_cb = function(job_options.exit_cb, job_options)

  let job = job_start(a:cmd, job_options)
  if job_status(job) ==# 'fail'
    call a:callback(0)
    return
  endif
  call ch_sendraw(job, '<call val="About"><unit /></call>')
  call timer_start(5000, {->a:callback(0)})
endfunction

