" =============
" CoqTopHandler
" =============

" + support for Coq 8.7

let s:xml = vital#coqpit#import('Web.XML')
let g:coqpit_debug = 1
let s:log = function('coqpit#logger#log')

let s:PowerAssert = vital#coqpit#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert

let s:start = function('coqpit#util#argsetup')
let s:get = function('coqpit#util#argget')
let s:end = function('coqpit#util#argend')

let s:job_start = function('coqpit#job#job_start')
let s:job_status = function('coqpit#job#job_status')
let s:job_stop = function('coqpit#job#job_stop')
let s:job_setoptions = function('coqpit#job#job_setoptions')
let s:ch_sendraw = function('coqpit#job#ch_sendraw')

let s:CoqTopHandler = {}

function! s:CoqTopHandler.new(...) abort
  call s:start(a:000)
  let l:args = s:get([])
  call s:end()

  let new = deepcopy(self)
  call new.restart(l:args)

  let new.trying_to_run = 1

  let new.info = {...->0}
  let new.add_axiom = {...->0}
  let new.after_callback_list = []
  let new.after_unexpected_exit = {...->0}
  let new.after_start = {...->0}

  return new
endfunction

" restart {{{
function! s:CoqTopHandler.restart(...) abort
  call s:start(a:000)
  let l:args = s:get([])
  call s:end()

  if self.running()
    let self.expected_running = 0
    call s:job_setoptions(self.job, {'exit_cb': {...->0}})
    call s:job_stop(self.job)
  endif

  let self.call_queue = []

  silent! unlet self.state_id
  silent! unlet self.job

  let self.waiting = v:null
  let self.abandon = 0
  let self.tip = -1

  call coqpit#coqtop#get_executable(self._make_restart_next(l:args))
endfunction

function! s:CoqTopHandler._make_restart_next(args) abort
  function! self.restart_next(cmd, data) abort closure
    if a:cmd is v:null
      echoerr '[coqpit.vim / CoqTop Handler] Not found executable CoqTop with following error messages.'
      for i in range(len(a:data[0]))
        echoerr '[' .. (i + 1) .. ': Command tried ] ' .. string(a:data[0][i])
        if has_key(a:data[1], i)
          echoerr '[' .. (i + 1) .. ': Error message ] ' .. a:data[1][i]
        endif
      endfor
      return
    endif

    let self.coq_version = a:data

    if !g:coqpit#options#get('silent') >= 1
      echo '[coqpit.vim / CoqTop Handler] CoqTop version ' .. self.coq_version .. ' started running.'
    endif

    let job_options = {}

    let job_options.out_cb = s:bind_itself(self._out_cb)
    let job_options.err_cb = s:bind_itself(self._err_cb)
    let job_options.exit_cb = s:bind_itself(self._exit_cb)

    let self.trying_to_run = 0
    let self.job = s:job_start(a:cmd, job_options)

    let self.expected_running = 1

    if !self.running()
      echoerr
        \ '[coqpit.vim / CoqTop Handler] Tried to start with '
        \ .. string(a:cmd)
        \ .. ' , but failed.'
      return
    endif

    call self.after_start()
  endfunction

  return function(self.restart_next, self)
endfunction
" }}}


" callback for job object {{{
function! s:CoqTopHandler._out_cb(msg) abort
  if !self.running() | return | endif

  let xml = s:xml.parse('<root>' . a:msg . '</root>')

  for value in xml.findAll('value')

    " NOTE : CoqTop sometimes sends <status> multiple times ....
    " FIXME : This is dirty hack.
    if len(value.child) == 1 && value.child[0].name ==# 'status' && !self.is_status
      continue
    endif

    exe s:assert('self.abandon >= 0')
    if self.abandon
      let self.abandon -= 1
      continue
    endif

    exe s:assert('self.waiting isnot v:null')

    let l:Callback = self.waiting
    let self.waiting = v:null
    let self.is_status = 0

    call l:Callback(value)

    for l:Callback in self.after_callback_list
      call l:Callback()
    endfor
  endfor


  for feedback in xml.findAll('feedback')
    let content = feedback.find('feedback_content')
    if get(get(content, 'attr', {}), 'val', '') ==# 'message'
      let state_id = str2nr(feedback.find('state_id').attr.val)
      let level = content.find('message_level').attr.val
      let msg = coqpit#xml#2str(content.find('richpp'))
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

  call self._check_call_queue()
endfunction
" }}}

function! s:CoqTopHandler._err_cb(msg) abort
  if !self.running() | return | endif
  echoerr "[coqpit.vim / CoqTop Handler] Internal error with following error message."
  echoerr a:msg
endfunction

function! s:CoqTopHandler._exit_cb(status) abort
  if self.expected_running
    let self.expected_running = 0
    echoerr '[coqpit.vim / CoqTop Handler] Unfortunately, CoqTop was exited with status '
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
    \ && s:job_status(self.job) == "run"
endfunction

function! s:CoqTopHandler.dead() abort
  return !self.trying_to_run && !self.running()
endfunction

function! s:CoqTopHandler.kill() abort
  if self.running()
    let self.expected_running = 0
    call s:job_stop(self.job)
    unlet self.job
  endif
endfunction

" }}}

" -- core functions {{{

function! s:CoqTopHandler._call(msg_func, cb, ...) abort
  call s:start(a:000)
  let l:is_status = s:get(0)
  call s:end()

  if self.dead() | return | endif

  call add(self.call_queue, [a:msg_func, a:cb, l:is_status])

  call self._check_call_queue()
endfunction
function! s:CoqTopHandler._check_call_queue() abort
  if !self.running() | return | endif
  if self.waiting isnot v:null | return | endif
  if len(self.call_queue) == 0 | return | endif

  let [l:Msg_func, l:Callback, l:is_status] = remove(self.call_queue, 0)
  let msg = l:Msg_func(self.tip)


  let self.waiting = l:Callback
  let self.is_status = l:is_status
  call s:ch_sendraw(self.job, msg .. "\n")
endfunction

function! s:CoqTopHandler.interrupt() abort
  if self.waiting isnot v:null
    let self.abandon = 1
    let self.waiting = v:null
  endif
  let self.tip = -1
  let self.call_queue = []
endfunction!

" }}}

" callback : (state_id, level, msg, err_loc) -> any
" set_info_callback(callback?) (empty to unset)
" info {{{
function! s:CoqTopHandler.set_info_callback(...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  let self.info = s:bind_itself(l:Callback)
endfunction
" }}}

" callback : (state_id) -> any
" set_add_axiom_callback(callback?) (empty to unset)
" add_axiom {{{
function! s:CoqTopHandler.set_add_axiom_callback(...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  let self.add_axiom = s:bind_itself(l:Callback)
endfunction
" }}}

" callback : () -> any
" add after_callback {{{
function! s:CoqTopHandler.add_after_callback(...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  call add(self.after_callback_list, s:bind_itself(l:Callback))
endfunction
" }}}

" callback : () -> any
" set_unexpected_exit_callback {{{
function! s:CoqTopHandler.set_unexpected_exit_callback(...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  let self.after_unexpected_exit = s:bind_itself(l:Callback)
endfunction
" }}}

" callback : () -> any
" set_start_callback( {{{
function! s:CoqTopHandler.set_start_callback(...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  let self.after_start = s:bind_itself(l:Callback)
endfunction
" }}}

" interacting with CoqTop using XML {{{


" ._init(callback)
" callback? : (state_id) -> any
"  send Init < init > {{{
function! s:CoqTopHandler._init(...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  call self._call({->
    \ '<call val="Init"><option val="none"/></call>'
    \ }, self._makeInitCallback(l:Callback))
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
" callback : (is_err, msg, err_loc) -> any
" send Add < send sentence > {{{
function! s:CoqTopHandler.send_sentence(sentence, ...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  " TODO : what is `editID` and `verbose` ?

  call self._call({state_id-> '
    \<call val="Add">
      \<pair>
        \<pair>
          \<string>' .. coqpit#xml#escape(a:sentence) .. '</string>
          \<int>-1</int>
        \</pair>
        \<pair>
          \<state_id val="' .. state_id .. '" />
          \<bool val="false" />
        \</pair>
      \</pair>
    \</call>
  \'}, self._makeAddCallback(l:Callback))
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
        let msg = coqpit#xml#2str(a:value.find('richpp'))
      endif

      call a:callback(state_id, 1, msg, err_loc)
    endif
  endfunction

  return function(self.addCallback, self)
endfunction
" }}}

" .refreshGoalInfo(callback) -> any
" callback : (is_err, goals_xml | err_mes, err_loc)
" send Goal < update Goals > {{{
function! s:CoqTopHandler.refreshGoalInfo(...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  call self._call({->
    \ '<call val="Goal"><unit /></call>'
    \ }, self._makeGoalCallback(l:Callback)
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
        let msg = coqpit#xml#2str(a:value.find('richpp'))
      endif

      call a:callback(state_id, 1, msg, err_loc)
    endif
  endfunction

  return function(self.goalCallback, self)
endfunction
" }}}

" callback : (is_err, state_id) -> any
" send EditAt < move tip > {{{
function! s:CoqTopHandler.edit_at(new_state_id, ...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  call self._call({->
    \ '<call val="Edit_at"><state_id val="' .. a:new_state_id .. '" /></call>'
    \ }, self._make_edit_at_callback(a:new_state_id, l:Callback))
endfunction
function! s:CoqTopHandler._make_edit_at_callback(new_state_id, callback) abort
  function! self.after_edit_at(value) abort closure
    if a:value.attr.val != 'good'
      let forced_state_id = str2nr(a:value.find('state_id').attr.val)
      let self.tip = forced_state_id
      call a:callback(1, forced_state_id)
    else
      let self.tip = a:new_state_id
      call a:callback(0, a:new_state_id)
    endif
  endfunction

  return function(self.after_edit_at, self)
endfunction
" }}}

" callback : (xml) -> any
" send Annotate < get structured code as XML > {{{
function! s:CoqTopHandler.annotate(code, ...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  call self._call({->
    \ '<call val="Annotate"><string>' .. coqpit#xml#escape(a:code) .. '</string></call>'
    \ }, self._make_after_annotate(l:Callback))
endfunction
function! s:CoqTopHandler._make_after_annotate(callback) abort
  function! self.after_annotate(value) abort closure
    call a:callback(a:value)
  endfunction

  return function(self.after_annotate, self)
endfunction
" }}}

" force = 0 : bool
" callback : (status_xml) -> any
" send Status < status > {{{
function! s:CoqTopHandler.status(...) abort
  call s:start(a:000)
  let l:force = s:get(0)
  let l:Callback = s:get({...->0})
  call s:end()

  call self._call({->
    \ '<call val="Status"><bool val="' .. (l:force ? 'true' : 'false') .. '"></bool></call>'
    \ }, self._make_after_status(l:Callback), 1)
endfunction
function! s:CoqTopHandler._make_after_status(callback) abort
  function! self.after_status(value) abort closure
    call a:callback(a:value)
  endfunction

  return function(self.after_status, self)
endfunction
" }}}

" callback : (is_err, err_msg, err_loc, msg) -> any
" send Query < query > {{{
function! s:CoqTopHandler.query(query_str, ...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  " TODO : what is the `route_id`
  let route_id = 0

  call self._call({state_id -> '
    \<call val="Query">
      \<pair>
        \<route_id val="' .. route_id .. '" />
        \<pair>
          \<string>' .. coqpit#xml#escape(a:query_str) .. '</string>
          \<state_id val="' .. state_id .. '" />
        \</pair>
      \</pair>
    \</call>
  \'}, self._make_after_query(l:Callback))
endfunction
function! s:CoqTopHandler._make_after_query(callback) abort
  function! self.after_query(value) abort closure
    let state_id = a:value.find('state_id')->get('attr', {})->get('val', -1)
    if a:value.attr.val ==# 'good'
      call a:callback(0, '', state_id, v:null,
        \   get(get(a:value.find('string'), 'child', {}), 0, '')
        \ )
    else
      let attr = a:value.attr

      let err_mes = coqpit#xml#2str(a:value.find('richpp'))
      let err_loc = v:null

      if has_key(attr, 'loc_s') && has_key(attr, 'loc_e')
        let err_loc = [str2nr(attr['loc_s']), str2nr(attr['loc_e'])]
      endif

      call a:callback(1, err_mes, state_id, err_loc, '')
    endif
  endfunction

  return function(self.after_query, self)
endfunction
" }}}

" }}}


" next sentence end pos in the tip
"
" state_id : int
" content : [string]
" from_pos : Pos
" callback : (is_err, err_mes, err_loc, pos) -> any
" next_sentence_end(state_id, content, from_pos, callback?) {{{
function! s:CoqTopHandler.next_sentence_end(state_id, content, from_pos, ...) abort
  call s:start(a:000)
  let l:Callback = s:get({...->0})
  call s:end()

  exe s:assert('a:state_id == self.tip')
  let code = join([a:content[a:from_pos[0]][a:from_pos[1]:]] + a:content[a:from_pos[0]+1:], "\n")
  call self.annotate(code, self._make_after_get_next_end(a:content, a:from_pos, l:Callback))
endfunction
function! s:CoqTopHandler._make_after_get_next_end(content, from_pos, callback) abort
  function! self.after_get_next_end(value) abort closure
    if a:value.attr.val == 'good'
      call a:callback(0, v:null, v:null, coqpit#annotate#associate(a:value, a:content, a:from_pos))
    else
      let attr = a:value.attr

      let err_mes = coqpit#xml#2str(a:value.find('richpp'))
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
  let element = s:xml.createElement(a:name)
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

function! coqpit#CoqTopHandler#new(...) abort
  return call(s:CoqTopHandler.new, a:000)
endfunction
