" ============
" Coquille IDE
" ============

" TODO : オプションで，編集で Infos/Goals は変わらないように
" TODO : 最悪 re-launch できますよ，は大事だよね
" TODO : Infos
" TODO : ハイライトをウィンドウ変項などに耐えるようにする

let s:PowerAssert = vital#vital#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert

let s:IDE = {}
let s:bufnr_to_IDE = {}

function! s:getIDE_by_bufnr(bufnr) abort
  return s:bufnr_to_IDE[a:bufnr]
endfunction

function! s:IDE.new(bufnr, args = []) abort
  " TODO : Use argss

  call self._register_buffer(a:bufnr)

  let self.GoalBuffers = []
  let self.InfoBuffers = []

  " checked by coq
  let self.sentence_end_pos_list = []

  " queued (exclusive)
  " List<[Pos, Pos]>
  " first is for internal, second is for apparence
  let self.queue = []

  " resulted by coqtop
  let self.state_id_list = []

  let self.colored = []
  let self.hls = []

  let self.goal_message = []
  let self.info_message = []
  let self.last_goal_check = -1
  let self.last_status_check = -1

  function! self.after_init(state_id) abort closure
    exe s:assert('len(self.sentence_end_pos_list) == 0 && len(self.state_id_list) == 0')
    call add(self.sentence_end_pos_list, [0, 0])
    call add(self.state_id_list, a:state_id)
    let self.last_goal_check = a:state_id
    call self._process_queue()
  endfunction

  let self.coqtop_handler = coquille#CoqTopHandler#new(a:args, function(self.after_init, self))
  call self.coqtop_handler.set_info_callback(self._info)
  call self.coqtop_handler.set_add_axiom_callback(self._add_axiom)
  call self.coqtop_handler.add_after_callback(self._check_queue)

  return self
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
    if self.coqtop_handler.waiting
      call self.coqtop_handler.interrupt()
    endif
    call self.coqtop_handler.editAt(self.state_id_list[-1], self._after_edit_at)
  endif
endfunction

" _state_id_to_range {{{
function! s:IDE._state_id_to_range(state_id) abort
  exe s:assert('len(self.sentence_end_pos_list) == len(self.state_id_list)')


  " binary serach
  let ok = 0
  let ng = len(self.state_id_list)
  while ng - ok > 1
    let mid = (ok + ng) / 2
    if self.state_id_list[mid] <= a:state_id
      let ok = mid
    else
      let ng = mid
    endif
  endwhile

  if get(self.state_id_list, ok, -1) != a:state_id
    return v:null
  endif

  return [
        \ get(self.sentence_end_pos_list, ok - 1, [0, 0]),
        \ self.sentence_end_pos_list[ok]
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
      call self._shrink_to(spos, v:none, 0)
      call add(self.hls, ["error", mes_range])
    elseif a:level == "warning"
      call add(self.hls, ["warning", mes_range])
    elseif a:level == "info"
    elseif a:level == ""
    else
      throw "Error: Unkown message level"
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
      echoerr '[Coquille IDE] Internal error.'
      call _process_queue()
      return
    endif

    let [spos, epos] = range

    call self._shrink_to(epos, v:none, 0)
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
function! s:IDE._shrink_to(pos, ceil=0, shrink_errors=1) abort
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

  if a:ceil && last[0] != -1 && last[1] != a:pos
    let updated -= 1
    if last[0] == 0
      call add(self.queue, last[1])
    elseif last[0] == 1
      call add(self.sentence_end_pos_list, last[1])
    endif
  endif

  for i in reverse(range(len(self.hls)))
    if s:pos_le(get(self.sentence_end_pos_list, -1, [0, 0]), self.hls[i][1][0])
      if a:shrink_errors || self.hls[i][0] == 'axiom'
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

" buffer caching {{{
function! s:IDE._register_buffer(bufnr) abort
  let s:bufnr_to_IDE[a:bufnr] = self
  let self.handling_bufnr = a:bufnr
  augroup coquille_buffer_change
    au!
    exe 'au TextChanged  <buffer=' .. a:bufnr .. '> call <SID>getIDE_by_bufnr(bufnr("%"))._after_textchange()'
    exe 'au TextChangedI <buffer=' .. a:bufnr .. '> call <SID>getIDE_by_bufnr(bufnr("%"))._after_textchange()'
    exe 'au TextChangedP <buffer=' .. a:bufnr .. '> call <SID>getIDE_by_bufnr(bufnr("%"))._after_textchange()'
  augroup END
endfunction

function! s:IDE._cache_buffer() abort
  let self.cached_buffer = self.getContent()
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

  call self._shrink_to(pos)

  call self.recolor()
  call self._check_queue()
endfunction
" }}}

" _check_queue {{{
function! s:IDE._check_queue() abort
  while len(self.queue) && s:pos_le(self.queue[-1][0], get(self.sentence_end_pos_list, -1, [0, 0]))
    call remove(self.queue, 0)
  endwhile

  if self.coqtop_handler.waiting == 0 && (
        \   len(self.queue) == 0
        \   || g:coquille#options#show_goal_always.get()
        \ )
    if self.last_goal_check != self.state_id_list[-1]
      exe s:assert('self.state_id_list[-1] == self.coqtop_handler.tip')
      let self.goal_message = []
      call self.coqtop_handler.refreshGoalInfo(self._goal)
      return
    endif
  endif

  if self.coqtop_handler.waiting == 0 && g:coquille#options#update_status_always.get()
    if self.last_status_check != self.state_id_list[-1]
      exe s:assert('self.state_id_list[-1] == self.coqtop_handler.tip')

      call self.coqtop_handler.status(v:none, self._status)
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
  for bufnr in self.GoalBuffers
    call deletebufline(bufnr, 1, '$')
    call setbufline(bufnr, 1, self.goal_message)
  endfor
endfunction

function! s:IDE.refreshInfo() abort
  for bufnr in self.InfoBuffers
    call deletebufline(bufnr, 1, '$')
    call setbufline(bufnr, 1, self.info_message)
  endfor
endfunction


" content informations {{{

" range : Range | null
"
" return [string]
function! s:IDE.getContent(range = v:null) abort
  if a:range is v:null
    return getbufline(self.handling_bufnr, 1, '$')
  endif

  let [spos, epos] = a:range
  let [sline, scol] = spos
  let [eline, ecol] = epos

  let lines = getbufline(self.handling_bufnr, sline + 1, eline + 1)

  let lines[eline-sline] = lines[eline-sline][:ecol]
  let lines[0] = lines[0][scol:]

  return lines
endfunction

function! s:IDE.maxlen() abort
  return max(map(self.getContent(), 'len(v:val)'))
endfunction

" }}}


" recolor {{{
function! s:IDE.recolor() abort
  call self._cache_buffer()

  for id in self.colored
    silent! call matchdelete(id)
  endfor
  let self.colored = []

  exe s:assert('len(self.state_id_list) == len(self.sentence_end_pos_list)')
  if len(self.state_id_list)
    let last_checked = self.sentence_end_pos_list[-1]
    let last_queued = self.get_apparently_last()

    exe s:assert('s:pos_le(last_checked, last_queued)')

    let maxlen = self.maxlen()

    let self.colored += s:matchaddrange(maxlen, "CoqChecked", [[0, 0], last_checked])
    let self.colored += s:matchaddrange(maxlen, "CoqQueued", [last_checked, last_queued])

    for [level, range] in self.hls
      " sweep error and warnings appearing after the top in advance
      let is_in_checked = s:pos_le(range[1], last_checked)
      if level == 'error'
        let group = is_in_checked ? 'CoqCheckedError' : 'CoqMarkedError'
        let priority = 30
      elseif level == 'warning'
        let group = is_in_checked ? 'CoqCheckedWarn' : 'CoqMarkedWarn'
        let priority = 20
      elseif level == 'axiom'
        let group = 'CoqCheckedAxiom'
        let priority = 20
      endif
      let self.colored += s:matchaddrange(maxlen, group, range, priority)
    endfor
  endif
endfunction
" }}}


" -- -- processing queue and callback

" process queue {{{
function! s:IDE._process_queue()
  if !self.coqtop_handler.running() || self.coqtop_handler.waiting || len(self.queue) == 0
    return
  endif

  exe s:assert('len(self.sentence_end_pos_list) == len(self.state_id_list)')
  exe s:assert('len(self.sentence_end_pos_list) >= 1')

  let last_checked = self.sentence_end_pos_list[-1]
  let next_queue = self.queue[0][0]


  if s:pos_le(next_queue, last_checked)
    call remove(self.queue, 0)
    call self._check_queue()
    return
  endif

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
      call self._process_queue()
      return
    endif

    if a:is_err
      call self._shrink_to(a:spos, v:none, 0)
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

      call self.coqtop_handler.send_sentence(a:state_id, sentence, self._make_after_result(a:state_id, sentence_range))
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
      return
    endif

    let content = self.getContent()

    if a:is_err
      " This easily occurs
      call self._shrink_to(spos, v:none, 0)
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

  if g:coquille#options#auto_move.get()
    call self.move(expected_sentence_end_pos)
  endif
endfunction
" }}}

" coq_back {{{
function! s:IDE.coq_back() abort
  if len(self.queue) > 0
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

  call self._shrink_to(self.get_apparently_last(), v:none, 0)
  call self.recolor()
  call self.refreshInfo()
  call self._check_queue()

  if g:coquille#options#auto_move.get()
    call self.move(self.get_apparently_last())
  endif
endfunction
" }}}

" _after_edit_at {{{
function! s:IDE._after_edit_at(is_err, state_id) abort
  if a:is_err
    let range = self._state_id_to_range(a:state_id)

    if range is v:null
      " TODO: restart
      throw "[Coquille IDE] internal error."
    endif

    let epos = range[1]

    if self._shrink_to(epos, v:none, 0)
      call self.recolor()
      call self._check_queue()
    endif
  else
    exe s:assert('index(self.state_id_list, a:state_id) >= 0')
    while self.state_id_list[-1] != a:state_id
      call remove(self.state_id_list[-1])
    endwhile
  endif
endfunction
" }}}

" coq_shrink_to_pos {{{
function! s:IDE.coq_shrink_to_pos(pos, ceil=0) abort
  if s:pos_le(self.get_apparently_last(), a:pos)
    return
  endif

  let content = self.getContent()

  let updated = self._shrink_to(a:pos, a:ceil, 0)
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

" coq_expand_to_pos {{{
function! s:IDE.coq_expand_to_pos(pos, ceil=0) abort
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
    let old_last = last
    let last = coqlang#next_sentence(content, last)

    if last is v:null
      if coquille#annotate#is_ending(content, old_last)
        let last = [len(content) - 1, len(content[-1])]
      else
        if !a:ceil && s:pos_lt(a:pos, old_last)
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

" coq_to_pos {{{
function! s:IDE.coq_to_pos(pos, ceil=0) abort
  let last = self.get_apparently_last()

  if s:pos_lt(a:pos, last)
    call self.coq_shrink_to_pos(a:pos, a:ceil)
  else
    call self.coq_expand_to_pos(a:pos, a:ceil)
  endif
endfunction
" }}}

" coq_to_cursor {{{
function! s:IDE.coq_to_cursor(ceil=v:null) abort
  if self.handling_bufnr != bufnr('%')
    return
  endif

  let curpos = getcurpos()[1:2]
  let pos = [curpos[0] - 1, curpos[1]]


  let ceil = 0

  if a:ceil isnot v:null
    ceil = a:ceil
  else
    let ceil = g:coquille#options#cursor_ceiling.get()
  endif

  call self.coq_to_pos(pos, ceil)
endfunction
" }}}

" coq_to_last {{{
function! s:IDE.coq_to_last(ceil=v:null) abort
  let content = self.getContent()

  call self.coq_to_pos([len(content), 0], 1)
endfunction
" }}}

" -- -- move (vim editor's cursor move)

function! s:IDE.focusing() abort
  return self.handling_bufnr == bufnr('%')
endfunction

function! s:IDE.move(pos) abort
  if self.focusing()
    let [line, col] = a:pos
    call cursor(line + 1, col)
  endif
endfunction



" internal {{{

function! s:matchaddrange(maxlen, group, range, priority=10, id=-1, dict={}) abort
  let [spos, epos] = a:range
  let [sline, scol] = spos
  let [eline, ecol] = epos

  if spos == epos
    return []
  endif

  let ids = []
  if sline == eline
    call add(ids, matchaddpos(a:group, [[sline + 1, scol + 1, ecol - scol]], a:priority, a:id, a:dict))
  else
    call add(ids, matchaddpos(a:group, [[sline + 1, scol + 1, a:maxlen + 1]], a:priority, a:id, a:dict))
    call add(ids, matchaddpos(a:group, [[eline + 1, 1, ecol]], a:priority, a:id, a:dict))
    let ids += s:matchaddlines(a:group, range(sline + 1, eline - 1), a:priority, a:id, a:dict)
  endif
  return ids
endfunction

function! s:matchaddlines(group, lines, priority=10, id=-1, dict={}) abort
  let ids = []
  for line in a:lines
    call add(ids, matchaddpos(a:group, [[line + 1]], a:priority, a:id, a:dict))
  endfor
  return ids
endfunction

function! s:first_change(c1, c2, line=0, col=0) abort
  let line = a:line
  let col = a:col
  while line < len(a:c1) && line < len(a:c2) && a:c1[line] == a:c2[line]
    let line += 1
  endwhile
  if line < len(a:c1) && line < len(a:c2)
    while col < len(a:c1[line]) && col < len(a:c2[line]) && a:c1[line][col] == a:c2[line][col]
      let col += 1
    endwhile
  endif
  return [line, col]
endfunction

function! s:pos_lt(pos1, pos2, eq=0) abort
  if a:eq
    return s:pos_le(a:pos1, a:pos2)
  endif
  return a:pos1[0] != a:pos2[0] ? a:pos1[0] < a:pos2[0] : a:pos1[1] < a:pos2[1]
endfunction

function! s:pos_le(pos1, pos2, eq=1) abort
  if !a:eq
    return s:pos_lt(a:pos1, a:pos2)
  endif
  return a:pos1[0] != a:pos2[0] ? a:pos1[0] < a:pos2[0] : a:pos1[1] <= a:pos2[1]
endfunction

function! s:steps(content, pos, num, newline_as_one = 0) abort
  let now = 0
  let [line, col] = a:pos
  let linenum = len(a:content)

  while line < linenum
    let newcol = col + a:num - now
    if newcol < len(a:content[line]) + a:newline_as_one
      return [line, newcol]
    else
      let now += max([len(a:content[line]) + a:newline_as_one - col, 0])

      let line += 1
      let col = 0
    endif
  endwhile
  return v:null
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
