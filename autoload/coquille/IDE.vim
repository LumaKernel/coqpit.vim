" ============
" Coquille IDE
" ============

let s:PowerAssert = vital#coquille#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert

let s:start = function('coquille#util#argsetup')
let s:get = function('coquille#util#argget')
let s:end = function('coquille#util#argend')

let s:IDE = {}
let s:bufnr_to_IDE = {}

function! s:getIDE_by_bufnr(bufnr) abort
  return s:bufnr_to_IDE[a:bufnr]
endfunction

" IDE.new {{{
function! s:IDE.new(bufnr, ...) abort
  call s:start(a:000)
  let l:args = s:get([])
  call s:end()

  let new = deepcopy(self)
  " TODO : Use args

  call new._register_buffer(a:bufnr)

  if has('nvim')
    let new.ns_id = nvim_create_namespace('')
  endif

  let new.highlight = g:coquille#options#get('highlight')
  let new.style_checked = g:coquille#options#get('highlight_style_checked')
  let new.style_queued = g:coquille#options#get('highlight_style_queued')

  let new.GoalBuffers = []
  let new.InfoBuffers = []

  let new.coqtop_handler = coquille#CoqTopHandler#new(l:args)

  call new.coqtop_handler.set_info_callback(new._info)
  call new.coqtop_handler.set_add_axiom_callback(new._add_axiom)
  call new.coqtop_handler.set_unexpected_exit_callback(new.restart)
  call new.coqtop_handler.set_start_callback(new.after_start)
  call new.coqtop_handler.add_after_callback(new._check_queue)

  call new.restart()

  return new
endfunction
" }}}

" IDE.restart {{{
function! s:IDE.restart() abort
  let self.keep_goal_info = 0

  call self.reset_colors()

  " checked by coq
  let self.sentence_end_pos_list = []

  " queued (exclusive)
  " List<[Pos, Pos]>
  " first is for internal, second is for apparence
  let self.queue = []
  let self.queueing = 0
:w

  " resulted by coqtop
  let self.state_id_list = []

  let self.colored = []
  let self.hls = []

  let self.goal_message = []
  let self.info_message = []
  let self.last_goal_check = -1
  let self.last_status_check = -1

  call self.refreshGoal()
  call self.refreshInfo()
endfunction

function! s:IDE.after_start() abort
  call self.coqtop_handler._init(self.after_init)
endfunction
" }}}

" IDE.rerun {{{
function! s:IDE.rerun() abort
  let self.keep_goal_info = 0

  call self.reset_colors()

  let last = self.get_apparently_last()

  let self.colored = []
  let self.hls = []

  let self.goal_message = []
  let self.info_message = []
  let self.last_goal_check = -1
  let self.last_status_check = -1

  function! self.after_edit_at2(...) abort closure
    call call(self._after_edit_at, a:000, self)
    call self.coq_expand_to_pos(last, 0)
  endfunction

  let self.queueing = 0
  call self.coqtop_handler.interrupt()

  if len(self.state_id_list) > 0
    call self.coqtop_handler.edit_at(self.state_id_list[0], self.after_edit_at2)
  else
    call self.coqtop_handler._init(self.after_init)
  endif

  call self.refreshGoal()
  call self.refreshInfo()
endfunction
" }}}

function! s:IDE.dead() abort
  return self.coqtop_handler.dead()
endfunction

function! s:IDE.kill()
  call self.reset_colors()

  let self.GoalBuffers = []
  let self.InfoBuffers = []

  call self.coqtop_handler.kill()
endfunction

function! s:IDE.after_init(state_id) abort
  exe s:assert('len(self.sentence_end_pos_list) == 0 && len(self.state_id_list) == 0')
  call add(self.sentence_end_pos_list, [0, 0])
  call add(self.state_id_list, a:state_id)
  let self.last_goal_check = a:state_id
  call self._process_queue()
endfunction

function! s:IDE.refresh() abort
  let self.keep_goal_info = 0
  call self.recolor()
  call self.refreshGoal()
  call self.refreshInfo()
endfunction



" -- private

function! s:IDE.is_initiated() abort
  return len(self.sentence_end_pos_list) > 0
endfunction

function! s:IDE.get_apparently_last() abort
  if len(self.queue) > 0
    return self.queue[-1][1]
  endif
  return get(self.sentence_end_pos_list, -1, [0, 0])
endfunction

function! s:IDE._after_shrink() abort
  if len(self.queue) == 0
    call self._interrupt_and_edit_at_top()
  endif
endfunction

function! s:IDE._interrupt_and_edit_at_top() abort
  if len(self.state_id_list) > 0
    let self.queueing = 0
    call self.coqtop_handler.interrupt()
    call self.coqtop_handler.edit_at(self.state_id_list[-1], self._after_edit_at)
  endif
endfunction

" _state_id_to_range {{{
function! s:IDE._state_id_to_range(state_id) abort
  exe s:assert('len(self.sentence_end_pos_list) == len(self.state_id_list)')

  let idx = index(self.state_id_list, a:state_id)
  if idx == -1 | return v:null | endif

  return [
        \ get(self.sentence_end_pos_list, idx - 1, [0, 0]),
        \ self.sentence_end_pos_list[idx]
        \]
endfunction
" }}}

" -- -- callbacks to CoqTopHandler operations {{{

" _info {{{
function! s:IDE._info(state_id, level, msg, loc) abort
  let range = self._state_id_to_range(a:state_id)
  if range is v:null
    call self._process_queue()
    return
  endif
  let [spos, epos] = range
  let content = self.getContent()

  let self.info_message += split(a:msg, "\n")

  if a:loc isnot v:null
    let [start, end] = a:loc
    let mes_range = [s:steps(content, spos, start, 1), s:steps(content, spos, end, 1)]

    exe s:assert('mes_range[0] isnot v:null')
    exe s:assert('mes_range[1] isnot v:null')

    if a:level == "error"
      call self._shrink_to(spos, v:null, 0)
      call add(self.hls, ["error", mes_range])
    elseif a:level == "warning"
      call add(self.hls, ["warning", mes_range])
    elseif a:level == "info"
    elseif a:level == ""
    endif
  endif

  call self.recolor()
  call self.refreshInfo()

  call self._check_queue()
endfunction
" }}}

" _goal {{{
function! s:IDE._goal(state_id, is_err, msg, err_loc) abort
  let content = self.getContent()

  if a:is_err
    let range = self._state_id_to_range(a:state_id)

    if range is v:null
      exe s:assert('0')
      call _process_queue()
      return
    endif

    let [spos, epos] = range

    call self._shrink_to(epos, v:null, 0)
    let self.queue = []

    if a:err_loc isnot v:null
      let [start, end] = a:err_loc
      let mes_range = [s:steps(content, epos, start, 1), s:steps(content, epos, end, 1)]
      call add(self.hls, ['error', mes_range])
    endif

    if a:msg != ''
      let self.info_message += split(a:msg, "\n")
    endif
  else
    if a:msg isnot v:null
      " a:msg is xml
      let self.goal_message = coquille#goals#xml2strs(a:msg)
    endif

    let self.last_goal_check = self.state_id_list[-1]
  endif

  call self.recolor()
  call self.refreshGoal()
  call self.refreshInfo()
  call self._check_queue()
endfunction
" }}}

" _status {{{
function! s:IDE._status(...) abort
  let self.last_status_check = self.state_id_list[-1]
endfunction
" }}}

" axiom {{{
function! s:IDE._add_axiom(state_id) abort
  let range = self._state_id_to_range(a:state_id)
  if range is v:null
    return
  endif

  let [spos, epos] = range

  call add(self.hls, ["axiom", range])

  call self.recolor()
  call self.refreshInfo()
endfunction
" }}}

" }}}

" Make the situation that
"   queue and sentence checked ends 
" floor : `pos` or right before
" ceil  : `pos` or right after
"
"
" pos : Pos | null
"
" shrink_errors=1 : this is for internal option
"
" return [bool] updated
" _shrink_to(pos, ceil=0, shrink_errors=1) {{{
function! s:IDE._shrink_to(pos, ...) abort
  call s:start(a:000)
  let l:ceil = s:get(0)
  let l:shrink_errors = s:get(1)
  call s:end()

  if a:pos is v:null
    return 0
  endif

  let last = [-1]
  let updated = 0

  while len(self.queue) > 0
        \ && s:pos_lt(a:pos, self.queue[-1][1])
    let last = [0, remove(self.queue, -1)]
    let updated += 1
  endwhile

  while len(self.sentence_end_pos_list) > 1
        \ && s:pos_lt(a:pos, self.sentence_end_pos_list[-1])
    let last = [1, remove(self.sentence_end_pos_list, -1)]
    let updated += 1
  endwhile

  if l:ceil && last[0] != -1 && last[1] != a:pos
    let updated -= 1
    if last[0] == 0
      call add(self.queue, last[1])
    elseif last[0] == 1
      call add(self.sentence_end_pos_list, last[1])
    endif
  endif

  for i in reverse(range(len(self.hls)))
    if s:pos_le(get(self.sentence_end_pos_list, -1, [0, 0]), self.hls[i][1][0])
      if l:shrink_errors || self.hls[i][0] == 'axiom'
        call remove(self.hls, i)
      endif
    endif
  endfor

  silent! unlet self.state_id_list[len(self.sentence_end_pos_list):-1]

  if updated > 0
    call self._after_shrink()
  endif

  return updated > 0
endfunction
" }}}

" _register_buffer {{{
function! s:IDE._register_buffer(bufnr) abort
  let s:bufnr_to_IDE[a:bufnr] = self
  let self.handling_bufnr = a:bufnr
  let self.unfocused = !self.focusing()

  exe 'augroup coquille_buffer_events_' .. a:bufnr
    au!
    exe 'au TextChanged  <buffer=' .. a:bufnr .. '> call <SID>getIDE_by_bufnr(' .. a:bufnr .. ')._after_textchange()'
    exe 'au TextChangedI <buffer=' .. a:bufnr .. '> call <SID>getIDE_by_bufnr(' .. a:bufnr .. ')._after_textchange()'
    exe 'au TextChangedP <buffer=' .. a:bufnr .. '> call <SID>getIDE_by_bufnr(' .. a:bufnr .. ')._after_textchange()'

    " :buffer to <this buffer>
    exe 'au BufEnter     <buffer=' .. a:bufnr .. '> call <SID>getIDE_by_bufnr(' .. a:bufnr .. ')._after_bufenter()'
    " :buffer to <another buffer>
    exe 'au BufEnter     * call <SID>getIDE_by_bufnr(' .. a:bufnr .. ')._after_bufenter()'
    " :split, :new, :tabnew, :tabp to <this buffer>
    exe 'au WinEnter     <buffer=' .. a:bufnr .. '> call <SID>getIDE_by_bufnr(' .. a:bufnr .. ')._after_bufenter()'
    " :split, :new, :tabnew, :tabp to <another buffer>
    exe 'au WinEnter     * call <SID>getIDE_by_bufnr(' .. a:bufnr .. ')._after_bufenter()'
  augroup END
endfunction
" }}}

" _cache_buffer {{{
function! s:IDE._cache_buffer() abort
  let self.cached_buffer = self.getContent()
endfunction
" }}}

" _after_bufenter {{{
function! s:IDE._after_bufenter() abort
  call self.recolor()
  if self.focusing()
    if self.unfocused
      " after focus

      if g:coquille#options#get('refresh_after_focus')
        call self.refreshGoal()
        call self.refreshInfo()
      endif

      if g:coquille#options#get('rerun_after_focus')
        call self.rerun()
      endif
    endif

    let self.unfocused = 0
  else
    let self.unfocused = 1
  endif
endfunction

" }}}

" make it as possible as lightweight
" _after_textchange {{{
function! s:IDE._after_textchange() abort
  let change = getchangelist(self.handling_bufnr)[0][-1]
  let content = self.getContent()

  if !exists('self.cached_buffer')
    return
  endif

  let pos = s:first_change(self.cached_buffer, content, max([change['lnum']-2, 0]), 0)

  if pos is v:null
    return
  endif

  " see 1 back because the right before is dot, the former sentence is broken
  if pos[0] < len(content) && pos[1] < len(content[pos[0]]) && !coqlang#is_blank(content[pos[0]][pos[1]])
    let pos[1] = max([0, pos[1]-1])
  endif

  if g:coquille#options#get('keep_after_textchange')
    let self.keep_goal_info = 1
  endif

  call self._shrink_to(pos)
  call self.recolor()

  call self._check_queue()
endfunction
" }}}

" _check_queue {{{
function! s:IDE._check_queue() abort
  if len(self.sentence_end_pos_list) == 0 | return | endif
  exe s:assert('len(self.sentence_end_pos_list) == len(self.state_id_list)')

  if self.queueing | return | endif

  while len(self.queue) && s:pos_le(self.queue[-1][0], self.sentence_end_pos_list[-1])
    call remove(self.queue, 0)
  endwhile

  if len(self.queue) == 0 || g:coquille#options#get('show_goal_always')
    if self.last_goal_check != self.state_id_list[-1]
      let self.goal_message = []
      call self.coqtop_handler.refreshGoalInfo(self._goal)
      return
    endif
  endif

  if g:coquille#options#get('update_status_always')
    if self.last_status_check != self.state_id_list[-1]
      call self.coqtop_handler.status(v:null, self._status)
      return
    endif
  endif

  call self._process_queue()
endfunction
" }}}

" -- public

function! s:IDE.addGoalBuffer(bufnr) abort
  if !count(self.GoalBuffers, a:bufnr)
    call add(self.GoalBuffers, a:bufnr)
  endif
endfunction

function! s:IDE.addInfoBuffer(bufnr) abort
  if !count(self.InfoBuffers, a:bufnr)
    call add(self.InfoBuffers, a:bufnr)
  endif
endfunction

function! s:IDE.refreshGoal() abort
  if self.dead() | return | endif
  if self.keep_goal_info | return | endif
  for bufnr in self.GoalBuffers
    call deletebufline(bufnr, 1, '$')
    call setbufline(bufnr, 1, self.goal_message)
  endfor
endfunction

function! s:IDE.refreshInfo() abort
  if self.dead() | return | endif
  if self.keep_goal_info | return | endif
  for bufnr in self.InfoBuffers
    call deletebufline(bufnr, 1, '$')
    call setbufline(bufnr, 1, self.info_message)
  endfor
endfunction


" content informations {{{

" range : Range | null
"
" return [string]
function! s:IDE.getContent(...) abort
  call s:start(a:000)
  let l:range = s:get(v:null)
  call s:end()

  if l:range is v:null
    return getbufline(self.handling_bufnr, 1, '$')
  endif

  if type(l:range) == v:t_number
    return getbufline(self.handling_bufnr, l:range + 1)[0]
  endif

  let [spos, epos] = l:range
  let [sline, scol] = spos
  let [eline, ecol] = epos

  let lines = getbufline(self.handling_bufnr, sline + 1, eline + 1)

  let lines[eline-sline] = lines[eline-sline][:ecol]
  let lines[0] = lines[0][scol:]

  return lines
endfunction

" }}}


" recolor {{{
function! s:IDE.reset_colors() abort
  if !exists('self.colored') | return | endif
  if !has('nvim')
    for [id, win_id] in self.colored
      silent! call matchdelete(id, win_id)
      let self.colored = []
    endfor
  else
    call nvim_buf_clear_namespace(self.handling_bufnr, self.ns_id, 0, -1)
  endif
endfunction
function! s:IDE.recolor() abort
  if self.dead() | return | endif
  call self._cache_buffer()
  call self.reset_colors()

  if !self.highlight | return | endif

  exe s:assert('len(self.state_id_list) == len(self.sentence_end_pos_list)')
  let last_checked = get(self.sentence_end_pos_list, -1, [0, 0])
  let last_queued = self.get_apparently_last()
  let content = self.getContent()

  " This can happen.
  " exe s:assert('s:pos_le(last_checked, last_queued)')

  let l:style_c = self.style_checked
  if l:style_c == 'all'
    call s:matchaddrange(self, "CoqChecked", [[0, 0], last_checked], -30)
  elseif l:style_c == 'last'
    if len(self.sentence_end_pos_list) > 1
      call s:matchaddrange(self, "CoqChecked", [self.sentence_end_pos_list[-2], last_checked], -30)
    else
      call s:matchaddrange(self, "CoqChecked", [[0, 0], last_checked], -30)
    endif
  elseif l:style_c == 'tail'
    for pos in self.sentence_end_pos_list
      call s:matchadd(self, "CoqChecked", pos[0], max([0, pos[1] - 1]), pos[1], -30)
    endfor
  elseif l:style_c == 'last_tail'
    call s:matchadd(self, "CoqChecked", last_checked[0], max([0, last_checked[1] - 1]), last_checked[1], -30)
  elseif l:style_c == 'last_line'
    call s:matchadd(self, "CoqChecked", last_checked[0], 0, last_checked[1], -30)
  endif

  let l:style_q = self.style_queued
  let l:style_q = g:coquille#options#get('highlight_style_queued')
  if s:pos_lt(last_checked, last_queued)
    if l:style_q == 'all'
      call s:matchaddrange(self, "CoqQueued", [last_checked, last_queued], -30)
    elseif l:style_q == 'last_tail'
      call s:matchadd(self, "CoqQueued", last_queued[0], max([0, last_queued[1] - 1]), last_queued[1], -30)
    elseif l:style_q == 'last_line'
      if last_checked[0] == last_queued[0]
        call s:matchadd(self, "CoqQueued", last_queued[0], last_checked[1], last_queued[1], -30)
      else
        call s:matchadd(self, "CoqQueued", last_queued[0], 0, last_queued[1], -30)
      endif
    endif
  endif


  for [level, range] in self.hls
    " sweep error and warnings appearing after the top in advance
    let is_in_checked = s:pos_le(range[1], last_checked)
    if level == 'error'
      let group = is_in_checked ? 'CoqCheckedError' : 'CoqMarkedError'
      let priority = -10
    elseif level == 'warning'
      let group = is_in_checked ? 'CoqCheckedWarn' : 'CoqMarkedWarn'
      let priority = -20
    elseif level == 'axiom'
      let group = 'CoqCheckedAxiom'
      let priority = -20
    endif
    call s:matchaddrange(self, group, range, priority)
  endfor
endfunction
" }}}


" -- -- processing queue and callback

" process queue {{{
function! s:IDE._process_queue()
  exe s:assert('len(self.sentence_end_pos_list) == len(self.state_id_list)')

  if !self.coqtop_handler.running()
        \ || len(self.queue) == 0
        \ || len(self.sentence_end_pos_list) == 0
        \ || self.state_id_list[-1] != self.coqtop_handler.tip
        \ || self.queueing
    return
  endif

  exe s:assert('len(self.sentence_end_pos_list) >= 1')

  let last_checked = self.sentence_end_pos_list[-1]
  let next_queue = self.queue[0][0]

  if s:pos_le(next_queue, last_checked)
    call remove(self.queue, 0)
    call self._check_queue()
    return
  endif

  let self.queueing = 1

  let state_id = self.state_id_list[-1]

  call self.coqtop_handler.next_sentence_end(state_id, self.getContent(), last_checked, self._make_after_get_sentence_end(state_id, last_checked))
endfunction
" }}}
" IDE._make_after_get_sentence_end(state_id, last_checked) {{{
function! s:IDE._make_after_get_sentence_end(state_id, spos) abort
  function! self.after_get_sentence_end(is_err, err_msg, err_loc, epos) abort closure

    if self.sentence_end_pos_list[-1] != a:spos
          \ || len(self.queue) == 0
          \ || a:state_id != self.state_id_list[-1]
      let self.queueing = 0
      call self._process_queue()
      return
    endif

    if a:is_err
      let self.queueing = 0
      call self._shrink_to(a:spos, v:null, 0)
      let self.queue = []

      if a:err_loc isnot v:null
        let [start, end] = a:err_loc
        let content = self.getContent()
        let mes_range = [s:steps(content, a:spos, start, 1), s:steps(content, a:spos, end, 1)]
        call add(self.hls, ["error", mes_range])
      endif

      if a:err_msg != ''
        let self.info_message += [a:err_msg]
      endif
    else
      if len(self.queue) == 1
        let self.queue[0][1] = a:epos
      endif
      let sentence_range = [a:spos, a:epos]
      let sentence = join(self.getContent(sentence_range), "\n")

      exe s:assert('a:state_id == self.coqtop_handler.tip')
      if a:state_id != self.coqtop_handler.tip
        call self._interrupt_and_edit_at_top()
        return
      endif

      call self.coqtop_handler.send_sentence(sentence, self._make_after_result(a:state_id, sentence_range))
    endif

    call self.recolor()
    call self.refreshInfo()
    " call self._check_queue()  " Don't do it
  endfunction

  return function(self.after_get_sentence_end, self)
endfunction
" }}}
" IDE._make_after_result(old_state_id, range) {{{
function! s:IDE._make_after_result(old_state_id, range) abort
  function! self.after_result(state_id, is_err, msg, err_loc) abort closure
    let [spos, epos] = a:range

    if self.sentence_end_pos_list[-1] != spos
          \ || len(self.queue) == 0
          \ || a:old_state_id != self.state_id_list[-1]
      let self.queueing = 0
      return
    endif

    let content = self.getContent()

    if a:is_err
      " This easily occurs
      let self.queueing = 0
      call self._shrink_to(spos, v:null, 0)
      let self.queue = []

      if a:err_loc isnot v:null
        let [start, end] = a:err_loc
        let mes_range = [s:steps(content, spos, start, 1), s:steps(content, spos, end, 1)]
        call add(self.hls, ["error", mes_range])
      endif

      if a:msg != ''
        let self.info_message += [a:msg]
      endif
    else
      call add(self.sentence_end_pos_list, epos)
      call add(self.state_id_list, a:state_id)
      let self.queueing = 0
    endif

    call self.recolor()
    call self.refreshInfo()
    call self._check_queue()
  endfunction

  return function(self.after_result, self)
endfunction
" }}}



" -- -- cursor move (cursor means last position which was not sent)

" coq_next {{{
function! s:IDE.coq_next() abort
  let self.keep_goal_info = 0

  let content = self.getContent()
  let last = self.get_apparently_last()

  if !coquille#annotate#is_ending(content, last)
    return
  endif

  let expected_sentence_end_pos = coqlang#next_sentence(content, last)

  if expected_sentence_end_pos is v:null
    let expected_sentence_end_pos = [len(content) - 1, len(content[-1])]
    " note : making return here is another good choice. but a compiler is more
    " correct.
  endif

  call self._shrink_to(last)  " for erasing errors

  if len(self.queue) == 0
    let self.info_message = []
  endif

  call add(self.queue, [[last[0], last[1] + 1], expected_sentence_end_pos])

  call self._process_queue()

  call self.recolor()
  call self.refreshInfo()

  if g:coquille#options#get('auto_move')
    call self.move(expected_sentence_end_pos)
  endif
endfunction
" }}}

" coq_back {{{
function! s:IDE.coq_back() abort
  let self.keep_goal_info = 0

  if len(self.queue) > 0
    if len(self.queue) == 1 && self.queueing
      let self.queueing = 0
      call self.coqtop_handler.interrupt()
    endif

    call remove(self.queue, -1)
    call self._after_shrink()
  elseif len(self.sentence_end_pos_list) > 1
    let self.info_message = []

    let removed = remove(self.sentence_end_pos_list, -1)
    silent! unlet self.state_id_list[len(self.sentence_end_pos_list):-1]

    call self._after_shrink()
  else
    return
  endif

  call self._shrink_to(self.get_apparently_last(), v:null, 0)
  call self.recolor()
  call self.refreshInfo()
  call self._check_queue()

  if g:coquille#options#get('auto_move')
    call self.move(self.get_apparently_last())
  endif
endfunction
" }}}

" _after_edit_at {{{
function! s:IDE._after_edit_at(is_err, state_id) abort
  if a:is_err
    let range = self._state_id_to_range(a:state_id)

    if range is v:null
      exe s:assert('0')
      return
    endif

    let epos = range[1]

    if self._shrink_to(epos, v:null, 0)
      call self.recolor()
      call self._check_queue()
    endif
  else
    exe s:assert('index(self.state_id_list, a:state_id) >= 0')
    if index(self.state_id_list, a:state_id) == -1 | return | endif
    while self.state_id_list[-1] != a:state_id
      call remove(self.state_id_list, -1)
      call remove(self.sentence_end_pos_list, -1)
    endwhile
    exe s:assert('len(self.state_id_list) == len(self.sentence_end_pos_list)')
  endif
endfunction
" }}}

" coq_shrink_to_pos(pos, ceil=0) {{{
function! s:IDE.coq_shrink_to_pos(pos, ...) abort
  call s:start(a:000)
  let l:ceil = s:get(0)
  call s:end()

  let self.keep_goal_info = 0

  if s:pos_le(self.get_apparently_last(), a:pos)
    return
  endif

  let content = self.getContent()

  let updated = self._shrink_to(a:pos, l:ceil, 0)
  if !updated
    return
  endif

  if len(self.queue) == 0
    let self.info_message = []
  endif

  call self.recolor()
  call self.refreshInfo()
endfunction
" }}}

" coq_expand_to_pos(pos, ceil=0) {{{
function! s:IDE.coq_expand_to_pos(pos, ...) abort
  call s:start(a:000)
  let l:ceil = s:get(0)
  call s:end()

  let self.keep_goal_info = 0

  let content = self.getContent()
  let last = self.get_apparently_last()

  let next_endpos = coqlang#next_sentence(content, last)

  if next_endpos is v:null
    return
  endif

  call self._shrink_to(last)

  if len(self.queue) == 0
    let self.info_message = []
  endif

  " let last_inclusive = [last[0], last[1] - 1]

  if s:pos_le(a:pos, last)
    return
  endif

  while s:pos_lt(last, a:pos)
    let last_internal = [last[0], last[1] + 1]
    let last = coqlang#next_sentence(content, last)

    if last is v:null
      exe s:assert('len(self.queue) > 0')
      if coquille#annotate#is_ending(content, self.queue[-1][1])
        let last = [len(content) - 1, len(content[-1])]
      else
        if !l:ceil && s:pos_lt(a:pos, self.queue[-1][0])
          call remove(self.queue, -1)
        endif

        break
      endif
    endif

    call add(self.queue, [last_internal, last])
  endwhile

  call self.recolor()
  call self.refreshInfo()
  call self._check_queue()
endfunction
" }}}

" coq_to_pos(pos, ceil = 0) {{{
function! s:IDE.coq_to_pos(pos, ...) abort
  call s:start(a:000)
  let l:ceil = s:get(0)
  call s:end()

  let last = self.get_apparently_last()

  if s:pos_lt(a:pos, last)
    call self.coq_shrink_to_pos(a:pos, l:ceil)
  else
    call self.coq_expand_to_pos(a:pos, l:ceil)
  endif
endfunction
" }}}

" coq_to_cursor(ceil={option's value}) {{{
function! s:IDE.coq_to_cursor(...) abort
  call s:start(a:000)
  let l:ceil = s:get()
  call s:end()

  if l:ceil is v:null
    let l:ceil = g:coquille#options#get('cursor_ceiling')
  endif

  if self.handling_bufnr != bufnr('%')
    return
  endif

  let curpos = getcurpos()[1:2]
  let pos = [curpos[0] - 1, curpos[1]]

  call self.coq_to_pos(pos, l:ceil)
endfunction
" }}}

" coq_to_last {{{
function! s:IDE.coq_to_last() abort
  let content = self.getContent()

  call self.coq_to_pos([len(content), 0], 1)
endfunction
" }}}

" query {{{
function! s:IDE.query(query_str) abort
  call self.coqtop_handler.query(a:query_str, self._make_after_query(a:query_str))
endfunction
function! s:IDE._make_after_query(query_str) abort
  function! self.after_query(is_err, err_msg, state_id, err_loc, msg) abort closure
    if a:is_err
      let range = self._state_id_to_range(a:state_id)
      if range isnot v:null && a:err_loc isnot v:null
        let [spos, epos] = range
        let content = self.getContent()
        let [start, end] = a:err_loc
        let mes_range = [s:steps(content, epos, start, 1), s:steps(content, epos, end, 1)]
        call add(self.hls, ['error', mes_range])
      endif
      if a:err_msg != ''
        let self.info_message += [a:err_msg]
      endif
    else
      let self.info_message += [a:msg]
    endif

    call self.recolor()
    call self.refreshInfo()
  endfunction

  return function(self.after_query, self)
endfunction
" }}}

function! s:IDE.clear_info() abort
  let self.keep_goal_info = 0
  let self.info_message = []
  call self.refreshInfo()
endfunction


" -- -- move (vim editor's cursor move)

function! s:IDE.focusing() abort
  return self.handling_bufnr == bufnr('%')
endfunction

function! s:IDE.move(pos) abort
  if self.focusing()
    let [line, col] = a:pos
    call cursor(line + 1, col + 1)
  endif
endfunction

function! s:IDE.move_to_top() abort
  call self.move(self.get_apparently_last())
endfunction



" internal {{{

function! s:matchaddrange(ide, group, range, priority) abort

  let [spos, epos] = a:range
  let [sline, scol] = spos
  let [eline, ecol] = epos

  let l:id = -1

  if spos == epos | return | endif

  if sline == eline
    call s:matchadd(a:ide, a:group, sline, scol, ecol, a:priority)
  else
    call s:matchadd(a:ide, a:group, sline, scol, len(a:ide.getContent(sline)) - scol, a:priority)
    call s:matchadd(a:ide, a:group, eline, 0, ecol, a:priority)
    for line in range(sline + 1, eline - 1)
      call s:matchadd(a:ide, a:group, line, 0, -1, a:priority)
    endfor
  endif
endfunction

" shim for matchaddpos and nvim_buf_add_highlight
function! s:matchadd(ide, group, line, scol, ecol, priority) abort
  if a:ecol != -1 && a:scol >= a:ecol | return | endif

  let ecol = a:ecol
  if !has('nvim')
    let l:id = -1
    if ecol == -1
      let ecol = len(a:ide.getContent(a:line))
    endif
    for win_id in win_findbuf(a:ide.handling_bufnr)
      let l:match_opt = {'window' : win_id}
      call add(a:ide.colored, [
          \ matchaddpos(a:group, [[a:line + 1, a:scol + 1, ecol - a:scol]],
          \   a:priority, l:id, l:match_opt), win_id])
    endfor
  else
    " if ecol != -1 | let ecol -= 1 | endif
    call nvim_buf_add_highlight(a:ide.handling_bufnr, a:ide.ns_id, a:group, a:line, a:scol, ecol)
  endif
endfunction

" pos_lt(pos1, pos2, eq=0)
function! s:pos_lt(pos1, pos2, ...) abort
  if a:0 && a:1
    return s:pos_le(a:pos1, a:pos2)
  endif
  return a:pos1[0] != a:pos2[0] ? a:pos1[0] < a:pos2[0] : a:pos1[1] < a:pos2[1]
endfunction

" pos_le(pos1, pos2, eq=1)
function! s:pos_le(pos1, pos2, ...) abort
  if !(a:0 && a:1)
    return s:pos_lt(a:pos1, a:pos2)
  endif
  return a:pos1[0] != a:pos2[0] ? a:pos1[0] < a:pos2[0] : a:pos1[1] <= a:pos2[1]
endfunction

function! s:steps(content, pos, num, newline_as_one) abort
  let now = 0
  let [line, col] = a:pos
  let linenum = len(a:content)

  while line < linenum
    exe s:assert('a:num >= now')
    let newcol = col + a:num - now
    if newcol < len(a:content[line]) + a:newline_as_one
      return [line, newcol]
    else
      let now += max([len(a:content[line]) - col, 0]) + a:newline_as_one

      let line += 1
      let col = 0
    endif
  endwhile

  " NOTE : it can happen in some situation; see dev/coq-examples/nasty_notations.v
  return [len(a:content) - 1, len(a:content[-1])]
endfunction

" }}}


" export

function! coquille#IDE#new(...) abort
  return call(s:IDE.new, a:000)
endfunction


" test {{{

function! coquille#IDE#Test()
  exe g:PAssert('s:pos_lt([0, 1], [0, 2])')
  exe g:PAssert('!s:pos_lt([0, 2], [0, 1])')
  exe g:PAssert('!s:pos_lt([0, 2], [0, 2])')
  exe g:PAssert('s:pos_lt([1, 2], [3, 4])')
  exe g:PAssert('!s:pos_lt([3, 3], [2, 2])')

  exe g:PAssert('s:pos_le([0, 1], [0, 2])')
  exe g:PAssert('!s:pos_le([0, 2], [0, 1])')
  exe g:PAssert('s:pos_le([0, 2], [0, 2])')
  exe g:PAssert('s:pos_le([1, 2], [3, 4])')
  exe g:PAssert('!s:pos_le([3, 3], [2, 2])')
endfunction

" }}}
