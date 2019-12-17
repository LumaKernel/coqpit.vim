" =============
" CoqTopHandler
" =============

" + support for Coq 8.7


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

  let self.job = job_start(coqtop_cmd, job_options)

  if !self.running()
    echoerr "[CoqTop Handler] coqtop is not running"
  endif
  call self._init(a:init_callback)
endfunction " }}}

" callback for job object {{{
function! s:CoqTopHandler._out_cb(channel, msg) abort
  " TODO : FOR DEBUG
  echom "got!!"
  echom a:msg

  let xml = webapi#xml#parse('<root>' . a:msg . '</root>')
  let g:gxml = xml  " TODO : FOR DEUBG

  if !empty(xml.find('value'))
    let self.waiting = 0
    let value = xml.find('value')

    call self.cb(value)

    let option = xml.find("value").find("option")
    call self._process_queue()
  endif


  for feedback in xml.findAll('feedback')
    let content = feedback.find('feedback_content')
    if content.attr.val == 'message'
      let state_id = feedback.find('state_id').attr.val
      let level = content.find('message_level').attr.val
      let msg = s:unescape(content.find('pp').child[0])
      let err_loc = v:null
      ECHO msg

      if level == 'error'
        let error_found = 1
      endif

      let loc = content.find("loc")
      if !empty(loc)
        let err_loc = [loc.attr.start, loc.attr.stop]
      endif

      call self.info(state_id, level, msg, err_loc)
    endif
  endfor
endfunction

function! s:CoqTopHandler._err_cb(channel, msg) abort
  " TODO
  echom "error!!"
  echoerr a:msg
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

function! s:CoqTopHandler._process_queue() abort
  if !self._initiated() || self.waiting
    return
  endif
  if len(self.sentenceQueue) > 0
    let front = remove(self.sentenceQueue, 0)
    call self.sendSentence(front[0], front[1])
  endif
endfunction


function! s:CoqTopHandler._call(msg, cb) abort
  if self.waiting
    return
  endif

  " TODO : FOR DEBUG
  echom "send!!"
  echom a:msg

  if self.running()
    let self.waiting = 1
    let self.cb = a:cb
    call ch_sendraw(self.job, a:msg . "\n")
  endif
endfunction

" }}}

" callback : (state_id, level, msg, err_loc)
" set_info_callback(callback?) (empty to unset)
" info {{{
function! s:CoqTopHandler.set_info_callback(callback = {...->0})
  let self.info = s:bind_itself(a:callback)
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
  function! s:initCallback(xml) abort closure
    let self.state_id = a:xml.find("state_id").attr.val
    call a:callback(self.state_id)
    call self._process_queue()
  endfunction

  return funcref('s:initCallback', self)
endfunction
" }}}

" .sendSentence(sentence, callback)
" callback : (state_id, is_err, msg, err_loc) -> any
" send Add < send sentence > {{{
function! s:CoqTopHandler.sendSentence(sentence, callback = {...->0}) abort
  call self._call('
    \<call val="Add">
      \<pair>
        \<pair>
          \' .. s:createElement("string", {}, a:sentence).toString() .. '
          \<int>-1</int>
        \</pair>
        \<pair>
          \<state_id val="' .. self.state_id .. '" />
          \<bool val="false" />
        \</pair>
      \</pair>
    \</call>
  \', self._makeAddCallback(a:callback))
endfunction
function! s:CoqTopHandler._makeAddCallback(callback) abort
  function! s:addCallback(value) abort closure
    let new_state_id = a:value.find("state_id").attr.val
    if a:value.attr.val == "good"
      let self.state_id = new_state_id
      call a:callback(new_state_id, 0, '', v:null)
    else
      let msg = ''
      let err_loc = v:null

      let attr = a:value.attr
      if has_key(attr, 'loc_s') && has_key(attr, 'loc_e')
        let err_loc = [attr['loc_s'], attr['loc_e']]
      endif

      if !empty(a:value.find('pp'))
        if len(a:value.find('pp').child)
          let msg = s:unescape(a:value.find('pp').child[0])
        endif
      endif

      call a:callback(new_state_id, 1, msg, err_loc)
    endif
  endfunction

  return funcref('s:addCallback', self)
endfunction
" }}}

" .refreshGoalInfo(callback)
" callback : TODO
" send Goal < update Goals > {{{
function! s:CoqTopHandler.refreshGoalInfo(callback = {...->0}) abort
  call self._call(
    \ '<call val="Goal"><unit /></call>'
    \ , self._makeGoalCallback(a:callback))
endfunction
function! s:CoqTopHandler._makeGoalCallback(callback) abort
  function! s:goalCallback(value) abort closure
    if a:value.attr.val == 'good'
      let option = a:value.find("option")
      if !empty(option)
        if has_key(option.attr, 'val') && option.attr['val'] == 'none'
          call a:callback([])
        endif
      else
        call a:callback(["hi"])
      endif
    endif
  endfunction

  return funcref('s:goalCallback', self)
endfunction
" }}}

" callback : (is_err, state_id)
" send EditAt < move tip > {{{
function! s:CoqTopHandler.editAt(new_state_id, callback = {...->0}) abort
  let self.new_state_id = a:new_state_id
  call self._call(
    \ '<call val="Edit_at"><state_id val="' .. a:new_state_id .. '" /></call>'
    \ , self._makeEditAtCallback(a:callback))
endfunction
function! s:CoqTopHandler._makeEditAtCallback(callback) abort
  function! s:editAtCallback(value) abort closure
    if a:value.attr.val != 'good'
      let new_state_id = a:value.find('state_id').attr.val
      call a:callback(1, f_state_id)
    else
      let self.state_id = self.new_state_id
      call a:callback(0, self.new_state_id)
    endif
  endfunction

  return funcref('s:editAtCallback', self)
endfunction
" }}}

" }}}


" -- sentence queue opreration {{{

function! s:CoqTopHandler.queueSentence(sentence, callback = v:null) abort
  call add(self.sentenceQueue, [a:sentence, a:callback])
  call self._process_queue()
endfunction

function! s:CoqTopHandler.clearSentenceQueue() abort
  let self.sentenceQueue = []
endfunction

function! s:CoqTopHandler.isQueueEmpty() abort
  return len(self.sentenceQueue) == 0
endfunction

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

function! s:unescape(str) abort
  return a:str
    \->substitute('&nbsp;', ' ', 'g')
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

