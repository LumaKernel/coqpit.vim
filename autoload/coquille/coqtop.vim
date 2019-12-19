" =============
" CoqTopHandler
" =============

" + support for Coq 8.7

let s:PowerAssert = vital#vital#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert

let s:CoqTopHandler = {}

function! s:CoqTopHandler.new(args = [], init_callback = {...->0}) abort
  call self.restart(a:args, a:init_callback)
  return self
endfunction

" restart {{{
function! s:CoqTopHandler.restart(args = [], init_callback = {...->0}) abort
  " TODO : user args
  silent! unlet self.state_id

  let self.sentenceQueue = []  " : List<[Sentence, any]>
  let self.waiting = 0
  let self.abandon = 0

  let coqtop_cmd = [
  \  'coqtop',
  \  '-ideslave',
  \  '-main-channel',
  \  'stdfds',
  \  '-async-proofs',
  \  'on'
  \  ]

  let job_options = {}

  let job_options.in_mode = 'raw'
  let job_options.out_mode = 'raw'
  let job_options.err_mode = 'nl'

  let job_options.out_cb = self._out_cb
  let job_options.err_cb = self._err_cb


  let self.info = {...->0}
  let self.add_axiom = {...->0}
  let self.after_callback_fns = []

  let self.job = job_start(coqtop_cmd, job_options)

  if !self.running()
    echoerr "[CoqTop Handler] coqtop is not running"
  endif
  call self._init(a:init_callback)
endfunction
" }}}

" callback for job object {{{
function! s:CoqTopHandler._out_cb(channel, msg) abort
  " TODO : FOR DEBUG
  echom "got!!"
  echom a:msg
  
  let xml = webapi#xml#parse('<root>' . a:msg . '</root>')
  let g:gxml = xml  " TODO : FOR DEUBG

  for value in xml.findAll('value')
    exe s:assert('self.abandon >= 0')
    if self.abandon
      let self.abandon -= 1
      continue
    endif

    exe s:assert('self.waiting == 1')

    let self.waiting = 0

    call self.cb(value)

    for Fn in self.after_callback_fns
      call Fn()
    endfor

    let option = xml.find("value").find("option")
  endfor


  for feedback in xml.findAll('feedback')
    let content = feedback.find('feedback_content')
    if content.attr.val == 'message'
      let state_id = str2nr(feedback.find('state_id').attr.val)
      let level = content.find('message_level').attr.val
      let msg = coquille#goals#richpp2str(content.find('richpp'))
      let err_loc = v:null

      if level == 'error'
        let error_found = 1
      endif

      let loc = content.find("loc")
      if !empty(loc)
        let err_loc = [loc.attr.start, loc.attr.stop]
      endif

      call self.info(state_id, level, msg, err_loc)
    elseif content.attr.val == 'addedaxiom'
      let state_id = str2nr(feedback.find('state_id').attr.val)
      call self.add_axiom(state_id)
    endif
  endfor
endfunction

function! s:CoqTopHandler._err_cb(channel, msg) abort
  " TODO
  echoerr "[CoqTop Handler] Internal error. Please report issue in " .. coquille#repository_url .. " ."
  echoerr msg
endfunction
" }}}

" -- process information {{{

function! s:CoqTopHandler._initiated() abort
  return exists("self.state_id")
endfunction

function! s:CoqTopHandler.running() abort
  return
    \ exists("self.job")
    \ && type(self.job) == v:t_job
    \ && job_status(self.job) == "run"
endfunction

function! s:CoqTopHandler.kill() abort
  if self.running()
    call job_stop(self.job, "term")
    unlet self.job
  endif
endfunction

" }}}

" -- core functions {{{

function! s:CoqTopHandler._call(msg, cb) abort
  if self.waiting
    return
  endif

  " TODO : FOR DEBUG
  " echom "send!!"
  " echom a:msg

  if self.running()
    let self.waiting = 1
    let self.cb = s:bind_itself(a:cb)
    call ch_sendraw(self.job, a:msg . "\n")
  endif
endfunction

function! s:CoqTopHandler.interrupt() abort
  if self.waiting
    let self.abandon += 1
    let self.tip = -1
    let self.waiting = 0
  endif
endfunction!

" }}}

" callback : (state_id, level, msg, err_loc) -> any
" set_info_callback(callback?) (empty to unset)
" info {{{
function! s:CoqTopHandler.set_info_callback(callback = {...->0})
  let self.info = s:bind_itself(a:callback)
endfunction
" }}}

" callback : (state_id) -> any
" set_add_axiom_callback(callback?) (empty to unset)
" add_axiom {{{
function! s:CoqTopHandler.set_add_axiom_callback(callback = {...->0})
  let self.add_axiom = s:bind_itself(a:callback)
endfunction
" }}}

" callback : () -> any
" add after_callback {{{
function! s:CoqTopHandler.add_after_callback(callback = {...->0})
  call add(self.after_callback_fns, s:bind_itself(a:callback))
endfunction
" }}}

" interacting with CoqTop User {{{ 


" ._init(callback)
" callback : (state_id) -> any
"  send Init < init > {{{
function! s:CoqTopHandler._init(callback = {...->0}) abort
  call self._call(
    \ '<call val="Init"><option val="none"/></call>'
    \ , self._makeInitCallback(a:callback))
endfunction
function! s:CoqTopHandler._makeInitCallback(callback) abort
  function! self.initCallback(xml) abort closure
    let state_id = str2nr(a:xml.find('state_id').attr.val)
    let self.tip = state_id
    call a:callback(state_id)
  endfunction

  return function(self.initCallback, self)
endfunction
" }}}

" .send_sentence(sentence, callback)
" callback : (state_id, is_err, msg, err_loc) -> any
" send Add < send sentence > {{{
function! s:CoqTopHandler.send_sentence(state_id, sentence, callback = {...->0}) abort
  exe s:assert('a:state_id == self.tip')
  call self._call('
    \<call val="Add">
      \<pair>
        \<pair>
          \' .. s:createElement("string", {}, a:sentence).toString() .. '
          \<int>-1</int>
        \</pair>
        \<pair>
          \<state_id val="' .. a:state_id .. '" />
          \<bool val="false" />
        \</pair>
      \</pair>
    \</call>
  \', self._makeAddCallback(a:callback))
endfunction
function! s:CoqTopHandler._makeAddCallback(callback) abort
  function! self.addCallback(value) abort closure
    let state_id = str2nr(a:value.find("state_id").attr.val)
    if a:value.attr.val == "good"
      let self.tip = state_id
      call a:callback(state_id, 0, '', v:null)
    else
      let msg = ''
      let err_loc = v:null

      let attr = a:value.attr
      if has_key(attr, 'loc_s') && has_key(attr, 'loc_e')
        let err_loc = [attr['loc_s'], attr['loc_e']]
      endif

      if !empty(a:value.find('richpp'))
        let msg = coquille#goals#richpp2str(a:value.find('richpp'))
      endif

      call a:callback(state_id, 1, msg, err_loc)
    endif
  endfunction

  return function(self.addCallback, self)
endfunction
" }}}

" .refreshGoalInfo(callback)
" callback : TODO
" send Goal < update Goals > {{{
function! s:CoqTopHandler.refreshGoalInfo(callback = {...->0}) abort
  call self._call(
    \ '<call val="Goal"><unit /></call>'
    \ , self._makeGoalCallback(a:callback)
    \ )
endfunction
function! s:CoqTopHandler._makeGoalCallback(callback) abort
  function! self.goalCallback(value) abort closure
    if a:value.attr.val == 'good'

      let option = a:value.find("option")
      if !empty(option) && has_key(option.attr, 'val') && option.attr['val'] == 'none'
        " No goal ( in CoqIDE, nothing is displayed )
        call a:callback(-1, 0, v:null, v:null)
      else
        call a:callback(-1, 0, a:value.find('goals'), v:null)
      endif
    else
      let state_id = str2nr(a:value.find("state_id").attr.val)
      let msg = ''
      let err_loc = v:null

      let attr = a:value.attr
      if has_key(attr, 'loc_s') && has_key(attr, 'loc_e')
        let err_loc = [attr['loc_s'], attr['loc_e']]
      endif

      if !empty(a:value.find('richpp'))
        let msg = coquille#goals#richpp2str(a:value.find('richpp'))
      endif

      call a:callback(state_id, 1, msg, err_loc)
    endif
  endfunction

  return function(self.goalCallback, self)
endfunction
" }}}

" callback : (is_err, state_id)
" send EditAt < move tip > {{{
function! s:CoqTopHandler.editAt(new_state_id, callback = {...->0}) abort
  call self._call(
    \ '<call val="Edit_at"><state_id val="' .. a:new_state_id .. '" /></call>'
    \ , self._makeEditAtCallback(a:new_state_id, a:callback))
endfunction
function! s:CoqTopHandler._makeEditAtCallback(new_state_id, callback) abort
  function! self.editAtCallback(value) abort closure
    if a:value.attr.val != 'good'
      let forced_state_id = str2nr(a:value.find('state_id').attr.val)
      let self.tip = forced_state_id
      call a:callback(1, forced_state_id)
    else
      let self.tip = a:new_state_id
      call a:callback(0, a:new_state_id)
    endif
  endfunction

  return function(self.editAtCallback, self)
endfunction
" }}}

" }}}




" internal functions

function! s:createElement(name, attr, ...) abort
  let element = webapi#xml#createElement(a:name)
  let element.attr = a:attr
  if a:0
    call element.value(a:000[0])
  endif
  return element
endfunction

function! s:bind_itself(fn) abort
  if type(get(a:fn, 'dict')) == v:t_dict
    return function(a:fn, get(a:fn, 'dict'))
  else
    return a:fn
  endif
endfunction


" Export

function! coquille#coqtop#makeInstance(...) abort
  return call(s:CoqTopHandler.new, a:000)
endfunction

function! coquille#coqtop#isExecutable() abort
  " TODO
  return 1
endfunction

function! coquille#coqtop#getVersion() abort
  " TODO
  return "1.0.0"
endfunction

