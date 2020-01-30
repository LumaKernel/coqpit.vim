
let s:xml = vital#coquille#import('Web.XML')

let s:job_start = function('coquille#job#job_start')
let s:job_status = function('coquille#job#job_status')
let s:ch_sendraw = function('coquille#job#ch_sendraw')

let s:to_check_default = [
    \ [
      \ 'coqidetop',
      \ '-main-channel',
      \ 'stdfds',
    \ ],
    \ [
      \ 'coqtop',
      \ '-ideslave',
      \ '-main-channel',
      \ 'stdfds',
    \ ]
  \ ]

" if config exists, use only that
" if that is list, use as it is
" if that is string, automatically select options
function! coquille#coqtop#get_executable(callback) abort
  let to_check = deepcopy(s:to_check_default)
  
  let opt = g:coquille#options#get('coq_executable', v:null)

  if type(opt) == v:t_list
    let to_check = [opt]
  elseif type(opt) == v:t_string
    let to_check[0][0] = opt
    let to_check[1][0] = opt
  endif

  let checker = {}
  let checker.done = {}
  let checker.res = {}

  function! checker.make_cb(i) abort closure
    function! self.cb(ok, err_mes) abort closure
      if get(self.done, a:i, 0)
        return
      endif
      let self.done[a:i] = 1
      if a:ok
        call a:callback(to_check[a:i], a:ok)
      else
        if a:err_mes != ''
          let self.res[a:i] = a:err_mes
        endif
        call self.check(a:i + 1)
      endif
    endfunction

    return self.cb
  endfunction

  function! checker.check(i) abort closure
    if a:i >= len(to_check)
      call a:callback(v:null, [to_check, self.res])
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

  function! job_options.out_cb(msg) abort closure
    let xml = s:xml.parse(a:msg)
    if xml.name !=# 'value' | return | endif
    if get(xml.attr, 'val') !=# 'good'
      return a:callback(0, 'Not recoginizable XML : ' .. a:msg)
    endif
    let coq_info = xml.find('coq_info')
    if empty(coq_info)
      return a:callback(0, 'Not recoginizable XML : ' .. a:msg)
    endif
    if !len(coq_info.child)
      return a:callback(0, 'Not recoginizable XML : ' .. a:mas)
    endif
    call a:callback(coquille#xml#2str(coq_info.child[0]), '')
  endfunction

  function! job_options.err_cb(msg) abort closure
    call a:callback(0, 'Unexpected error : ' .. a:msg)
  endfunction

  function! job_options.exit_cb(exit_status) abort closure
    call a:callback(0, 'Unexpected exit : ' .. exit_status)
  endfunction

  let job_options.out_cb = function(job_options.out_cb, job_options)
  let job_options.err_cb = function(job_options.err_cb, job_options)
  let job_options.exit_cb = function(job_options.exit_cb, job_options)

  try
    let job = s:job_start(a:cmd, job_options)
  catch /.*/
    call a:callback(0, 'Fail to start job : ' .. v:exception)
    return
  endtry
  if s:job_status(job) ==# 'fail'
    call a:callback(0, '')
    return
  endif
  call s:ch_sendraw(job, '<call val="About"><unit /></call>' .. "\n")
  call timer_start(10000, {->a:callback(0, 'Timeout')})
endfunction

