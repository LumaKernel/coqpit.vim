" =============
" CoqTopHandler
" =============

" + support for Coq 8.7


let s:PowerAssert = vital#vital#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert


let s:CoqTopHandler = {}

function! s:CoqTopHandler.new(args = []) abort
  let new = deepcopy(self)
  call new.restart(a:args)

  let new.info = {...->0}
  let new.add_axiom = {...->0}
  let new.after_callback_fns = []
  let new.after_unexpected_exit = {...->0}
  let new.after_start = {...->0}

  return new
endfunction

" restart {{{
function! s:CoqTopHandler.restart(args = []) abort
  if self.running()
    let self.expected_running = 0
    call job_stop(self.job, 'term')
  endif

  silent! unlet self.state_id
  silent! unlet self.job

  let self.waiting = 0
  let self.abandon = 0

  call coquille#coqtop#get_executable(self._make_restart_next(a:args))
endfunction

function! s:CoqTopHandler._make_restart_next(args) abort
  function! self.restart_next(cmd, version) abort closure
    if a:cmd is v:null
      throw '[CoqTop Handler] Not found executable CoqTop.'
    endif

    ECHO a:version

    let job_options = {}

    let job_options.in_mode = 'raw'
    let job_options.out_mode = 'raw'
    let job_options.err_mode = 'nl'

    let job_options.out_cb = self._out_cb
    let job_options.err_cb = self._err_cb
    let job_options.exit_cb = self._exit_cb

    let self.job = job_start(a:cmd, job_options)

    if !self.running()
      throw
        \ '[CoqTop Handler] Tried to start with '
        \ .. webapi#json#encode(a:cmd)
        \ .. ' , but failed.'
    endif

    let self.expected_running = 1
    call self.after_start()
  endfunction

  return function(self.restart_next, self)
endfunction
" }}}


" callback for job object {{{
function! s:CoqTopHandler._out_cb(channel, msg) abort
  if !self.running() || a:channel isnot job_getchannel(self.job) | return | endif
  " TODO : FOR DEBUG
  let g:mymes += ["got!!"]
  let g:mymes += [a:msg]
  
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
      let msg = coquille#xml#2str(content.find('richpp'))
      let err_loc = v:null

      let loc = content.find("loc")
      if !empty(loc)
        let err_loc = [str2nr(loc.attr.start), str2nr(loc.attr.stop)]
      endif

      call self.info(state_id, level, msg, err_loc)
    elseif content.attr.val == 'addedaxiom'
      let state_id = str2nr(feedback.find('state_id').attr.val)
      call self.add_axiom(state_id)
    endif
  endfor
endfunction
" }}}

function! s:CoqTopHandler._err_cb(channel, msg) abort
  if !self.running() || a:channel isnot job_getchannel(self.job) | return | endif
  " TODO
  echoerr "[CoqTop Handler] Internal error. Please report issue in " .. g:coquille#repository_url .. " ."
  echoerr a:msg
endfunction

function! s:CoqTopHandler._exit_cb(channel, status) abort
  " if a:channel isnot job_getchannel(self.job) | return | endif
  if self.expected_running
    let self.expected_running = 0
    echoerr '[CoqTop Handler] Unfortunately, CoqTop was exited with status '
          \ .. a:status
          \ .. '. Handler will try to restart.'
    call self.restart()
    call self.after_unexpected_exit()
  endif
endfunction

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
    let self.expected_running = 0
    call job_stop(self.job, 'term')
    unlet self.job
  endif
endfunction

" }}}

" -- core functions {{{

function! s:CoqTopHandler._call(msg, cb) abort
  if self.waiting
    exe s:assert('0')
    return
  endif

  " TODO : FOR DEBUG
  let g:mymes += ["send!!"]
  let g:mymes += [a:msg]

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

" callback : () -> any
" set_unexpected_exit_callback {{{
function! s:CoqTopHandler.set_unexpected_exit_callback(callback = {...->0})
  let self.after_unexpected_exit = s:bind_itself(a:callback)
endfunction
" }}}

" callback : () -> any
" set_start_callback( {{{
function! s:CoqTopHandler.set_start_callback(callback = {...->0})
  let self.after_start = s:bind_itself(a:callback)
endfunction
" }}}

" interacting with CoqTop {{{


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
          \<string>' .. coquille#xml#escape(a:sentence) .. '</string>
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
        let err_loc = [str2nr(attr['loc_s']), str2nr(attr['loc_e'])]
      endif

      if !empty(a:value.find('richpp'))
        let msg = coquille#xml#2str(a:value.find('richpp'))
      endif

      call a:callback(state_id, 1, msg, err_loc)
    endif
  endfunction

  return function(self.addCallback, self)
endfunction
" }}}

" .refreshGoalInfo(callback) -> any
" callback : (state_id, is_err, goals_xml | err_mes, err_loc)
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
        let err_loc = [str2nr(attr['loc_s']), str2nr(attr['loc_e'])]
      endif

      if !empty(a:value.find('richpp'))
        let msg = coquille#xml#2str(a:value.find('richpp'))
      endif

      call a:callback(state_id, 1, msg, err_loc)
    endif
  endfunction

  return function(self.goalCallback, self)
endfunction
" }}}

" callback : (is_err, state_id) -> any
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

" callback : (xml) -> any
" send Annotate < get structured code as XML > {{{
function! s:CoqTopHandler.annotate(code, callback = {...->0}) abort
  call self._call(
    \ '<call val="Annotate"><string>' .. coquille#xml#escape(a:code) .. '</string></call>'
    \ , self._make_after_annotate(a:callback))
endfunction
function! s:CoqTopHandler._make_after_annotate(callback) abort
  function! self.after_annotate(value) abort closure
    call a:callback(a:value)
  endfunction

  return function(self.after_annotate, self)
endfunction
" }}}

" callback : (status_xml) -> any
" send Status < status > {{{
function! s:CoqTopHandler.status(force = 0, callback = {...->0}) abort
  call self._call(
    \ '<call val="Status"><bool val="' .. (a:force ? 'true' : 'false') .. '"></bool></call>'
    \ , self._make_after_status(a:callback))
endfunction
function! s:CoqTopHandler._make_after_status(callback) abort
  function! self.after_status(value) abort closure
    call a:callback(a:value)
  endfunction

  return function(self.after_status, self)
endfunction
" }}}

" }}}


" next sentence end pos in the tip
"
" state_id : int
" content : [string]
" from_pos : Pos
" callback : (is_err, err_mes, err_loc, pos) -> any
" next_sentence_end(state_id, content, from_pos, callback) {{{
function! s:CoqTopHandler.next_sentence_end(state_id, content, from_pos, callback = {...->0}) abort
  exe s:assert('a:state_id == self.tip')
  let code = join([a:content[a:from_pos[0]][a:from_pos[1]:]] + a:content[a:from_pos[0]+1:], "\n")
  call self.annotate(code, self._make_after_get_next_end(a:content, a:from_pos, a:callback))
endfunction
function! s:CoqTopHandler._make_after_get_next_end(content, from_pos, callback) abort
  function! self.after_get_next_end(value) abort closure
    if a:value.attr.val == 'good'
      call a:callback(0, v:null, v:null, coquille#annotate#associate(a:value, a:content, a:from_pos))
    else
      let attr = a:value.attr

      let err_mes = coquille#xml#2str(a:value.find('richpp'))
      let err_loc = v:null

      if has_key(attr, 'loc_s') && has_key(attr, 'loc_e')
        let err_loc = [str2nr(attr['loc_s']), str2nr(attr['loc_e'])]
      endif

      call a:callback(1, err_mes, err_loc, v:null)
    endif
  endfunction

  return function(self.after_get_next_end, self)
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

function! s:bind_itself(fn) abort
  if type(get(a:fn, 'dict')) == v:t_dict
    return function(a:fn, get(a:fn, 'dict'))
  else
    return a:fn
  endif
endfunction


" Export

function! coquille#CoqTopHandler#new(...) abort
  return call(s:CoqTopHandler.new, a:000)
endfunction
