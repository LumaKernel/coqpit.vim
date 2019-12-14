" ============
" CoqTopDriver
" ============

" + support for Coq 8.7


let s:CoqTopDriver = {}

function! s:CoqTopDriver.new(args = []) abort
  call self.restart(a:args)
  return self
endfunction

" restart {{{
function! s:CoqTopDriver.restart(args = []) abort
  " TODO : user args
  let self.states = []
  silent! unlet self.root_state
  silent! unlet self.state_id

  let self.payloads = []
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

  let self.job = job_start(coqtop_cmd, job_options)
  " let self.channel = job_getchannel(self.job)

  if !self.running()
    echoerr "coqtop is not running"
  endif
  call self._init()
endfunction " }}}

" callback for job object {{{
function! s:CoqTopDriver._out_cb(channel, msg) abort
  " TODO : FOR DEBUG
  echom "got!!"
  echom a:msg
  let self.waiting = 0

  let xml = webapi#xml#parse('<root>' . a:msg . '</root>')
  let g:gxml = xml  " TODO : FOR DEUBG

  call self.cb(xml)

  call self._process_queue()
endfunction

function! s:CoqTopDriver._err_cb(channel, msg) abort
  " TODO
  echom "error!!"
  echoerr a:msg
endfunction
" }}}

" -- process information

function! s:CoqTopDriver._initiated() abort
  return exists("self.root_state")
endfunction

function! s:CoqTopDriver.running() abort
  return
    \ exists("self.job")
    \ && type(self.job) == v:t_job
    \ && job_status(self.job) == "run"
endfunction

function! s:CoqTopDriver.kill() abort
  if self.running()
    call job_stop(self.job, "term")
    unlet self.job
  endif
endfunction


" -- core functions

function! s:CoqTopDriver._process_queue() abort
  if !self._initiated() || self.waiting
    return
  endif
  if len(self.sentenceQueue) > 0
    let front = remove(self.sentenceQueue, 0)
    call self.sendSentence(front[0], front[1])
  endif
endfunction


function! s:CoqTopDriver._call(msg, cb) abort
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


" interacting with 

" reporting info to CoqTop user
function! s:CoqTopDriver.info(state_id, level, msg, err_loc)
  if exists("self.info_cb")
    call self.info_cb(a:state_id, a:level, a:msg, a:err_loc, self.payloads[0])
  endif
endfunction

" reporting result (of sending sentences) to CoqTop user
function! s:CoqTopDriver.result(state_id, is_err, msg, err_loc)
  if exists("self.result_cb")
    call self.result_cb(a:state_id, a:is_err, a:msg, a:err_loc, self.payloads[0])
  endif
endfunction

function! s:CoqTopDriver.goal(goals)
  if exists("self.goal_cb")
    call self.goal_cb(a:goals)
  endif
endfunction

function! s:CoqTopDriver.currentState() abort
  if len(self.states) == 0
    return self.root_state
  else
    return self.state_id
  endif
endfunction


"  send Init < init > {{{
function! s:CoqTopDriver._init() abort
  call self._call(
    \ '<call val="Init"><option val="none"/></call>'
    \ , self._sendInitCallback)
endfunction
function! s:CoqTopDriver._sendInitCallback(xml) abort
  echom "Init Callback"
  let self.state_id = a:xml.find("state_id").attr.val
  let self.root_state = self.state_id
  call self._process_queue()
endfunction  " }}}


" send Add < send sentence > {{{
function! s:CoqTopDriver.sendSentence(sentence, payload = v:null) abort
  call add(self.payloads, a:payload)
  call self._call('
    \<call val="Add">
      \<pair>
        \<pair>
          \' . s:createElement("string", {}, a:sentence).toString() . '
          \<int>-1</int>
        \</pair>
        \<pair>
          \' . s:createElement("state_id", {"val": self.currentState()}).toString() . '
          \<bool val="false"/>
        \</pair>
      \</pair>
    \</call>
  \', self._sendAddCallback)
endfunction
function! s:CoqTopDriver._sendAddCallback(xml) abort
  echom "Add Callback"
  let value = a:xml.find("value")
  let new_state_id = value.find("state_id").attr.val
  if value.attr.val == "good"
    call add(self.states, new_state_id)
    let self.state_id = new_state_id
    call self.result(new_state_id, 0, '', v:null)
  else
    let msg = ''
    let err_loc = v:null

    let attr = value.attr
    if has_key(attr, 'loc_s') && has_key(attr, 'loc_e')
      let err_loc = [attr['loc_s'], attr['loc_e']]
    endif

    if !empty(value.find('pp'))
      if len(value.find('pp').child)
        let msg = s:unescape(a:xml.find('pp').child[0])
      endif
    endif

    call self.result(new_state_id, 1, msg, err_loc)
  endif
  call remove(self.payloads, 0)
endfunction  " }}}


" send Goal < update Goals > {{{
function! s:CoqTopDriver.refreshGoalInfo(payload = v:null) abort
  call add(self.payloads, a:payload)
  call self._call(
    \ '<call val="Goal"><unit /></call>'
    \ , self._sendGoalCallback)
endfunction
function! s:CoqTopDriver._sendGoalCallback(xml) abort
  let error_found = 0
  for feedback in a:xml.findAll('feedback')
    let content = feedback.find('feedback_content')
    if content.attr.val == 'message'
      let state_id = feedback.find('state_id').attr.val
      let level = content.find('message_level').attr.val
      let msg = s:unescape(content.find('pp').child[0])
      let err_loc = v:null

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
  " TODO
  " if error_found
  "   return
  " endif
  if a:xml.find("value").attr.val == 'good'
    let option = a:xml.find("value").find("option")
    if !empty(option)
      if has_key(option.attr, 'val') && option.attr['val'] == 'none'
        call self.goal([])
      endif
    else
      call self.goal(["hi"])
    endif
  endif
  call remove(self.payloads, 0)
endfunction  " }}}


function! s:CoqTopDriver.queueSentence(sentence, payload = v:null) abort
  call add(self.sentenceQueue, [a:sentence, a:payload])
  call self._process_queue()
endfunction

function! s:CoqTopDriver.clearSentenceQueue() abort
  let self.sentenceQueue = []
endfunction


" set callback function for Infos
" cb : (
"   message_level: string,
"   message: string,
"   location: [start, end] | null,
"   payload: any,
" ) => any
" - message levels
"   - error
"   - warning
"   - info
function! s:CoqTopDriver.setInfoCallback(info_cb)
  let self.info_cb = a:info_cb
endfunction

function! s:CoqTopDriver.setResultCallback(result_cb)
  let self.result_cb = a:result_cb
endfunction

" set callback function for Goals
" cb : (xml) => any
function! s:CoqTopDriver.setGoalCallback(goal_cb)
  let self.goal_cb = a:goal_cb
endfunction


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


" Export

function! coquille#coqtop#makeInstance(args = []) abort
  return s:CoqTopDriver.new(a:args)
endfunction

function! coquille#coqtop#isExecutable() abort
  " TODO
  return 1
endfunction

function! coquille#coqtop#getVersion() abort
  " TODO
  return "1.0.0"
endfunction

