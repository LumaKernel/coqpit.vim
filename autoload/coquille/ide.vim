" ============
" Coquille IDE
" ============

" TODO : Goals

" TODO : オプションで，編集で Infos/Goals は変わらないように
" TODO : 最悪 re-launch できますよ，は大事だよね
" TODO : Infos
" TODO : ハイライトをウィンドウ変項などに耐えるようにする

let s:PowerAssert = vital#vital#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert

let s:IDE = {}
let s:bufnr_to_IDE = {}

let s:auto_move = coquille#config_name('auto_move', 0)
let s:cursor_ceiling = coquille#config_name('cursor_ceiling', 0)
let s:strict_check = coquille#config_name('strict_check', 1)

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
  let self.queue = []
  " resulted by coqtop
  let self.state_id_list = []

  let self.colored = []
  let self.hls = []

  let self.goal_message = []
  let self.info_message = []
  let self.last_goal_check = -1

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

function! s:IDE.get_last() abort
  return get(self.queue, -1, get(self.sentence_end_pos_list, -1, [0, 0]))
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

" info {{{
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

" goal {{{
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
  endif

  call self.recolor()
  call self.refreshGoal()
  call self.refreshInfo()
  call self._check_queue()
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

" pos : Pos | null
"
" <pos> [shrinked range] (old range)
"
" shrink_errors=1 : this is for internal option
"
" return [bool] updated
" _shrink_to(pos, ceil=0) {{{
function! s:IDE._shrink_to(pos, ceil=0, shrink_errors=1) abort
  if a:pos is v:null
    return 0
  endif

  let last = [-1]
  let updated = 0

  while len(self.queue) > 0
        \ && s:pos_lt(a:pos, self.queue[-1])
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
    if s:pos_le(self.sentence_end_pos_list[-1], self.hls[i][1][0])
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
  if self.coqtop_handler.waiting == 0
      \ && (len(self.queue) == 0 || coquille#get_buffer_config(s:strict_check, 0))
    if self.last_goal_check != self.state_id_list[-1]
      exe s:assert('self.state_id_list[-1] == self.coqtop_handler.tip')
      let self.goal_message = []
      let self.last_goal_check = self.state_id_list[-1]
      call self.coqtop_handler.refreshGoalInfo(self._goal)
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

  if len(self.state_id_list)
    let last_checked = self.sentence_end_pos_list[-1]
    let last_queued = get(self.queue, -1, last_checked)

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

  let last_checked = self.sentence_end_pos_list[-1]
  let next_queue = self.queue[0]

  let sentence_range = [last_checked, next_queue]
  let sentence = join(self.getContent(sentence_range), "\n")
  let state_id = self.state_id_list[-1]

  call self.coqtop_handler.send_sentence(state_id, sentence, self._make_after_result(sentence_range))
endfunction
" }}}
" IDE._make_after_result(range) {{{
function! s:IDE._make_after_result(range) abort
  function! self.after_result(state_id, is_err, msg, err_loc) abort closure
    let [spos, epos] = a:range

    if self.sentence_end_pos_list[-1] != spos || len(self.queue) == 0
      call self._process_queue()
      return
    endif

    let content = self.getContent()
    let next_queue = self.queue[0]

    " this result is for self.queue[0]

    call remove(self.queue, 0)

    if a:is_err
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
      call add(self.sentence_end_pos_list, next_queue)
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
  let last = self.get_last()
  let sentence_end_pos = coqlang#nextSentencePos(content, last)

  if sentence_end_pos is v:null
    return
  endif

  call self._shrink_to(last)

  if len(self.queue) == 0
    let self.info_message = []
  endif

  call add(self.queue, sentence_end_pos)

  call self._process_queue()

  call self.recolor()
  call self.refreshInfo()

  if coquille#get_buffer_config(s:auto_move, 0)
    call self.move(sentence_end_pos)
  endif
endfunction
" }}}

" coq_back {{{
function! s:IDE.coq_back() abort
  if !self.is_initiated()
    return
  endif

  if len(self.queue) > 0
    call remove(self.queue, -1)
    call self._after_shrink()
  elseif len(self.sentence_end_pos_list) > 1
    let self.info_message = []

    let removed = remove(self.sentence_end_pos_list, -1)
    silent! unlet self.state_id_list[len(self.sentence_end_pos_list):-1]

    call self._after_shrink()
  else
    exe s:assert('len(self.sentence_end_pos_list) == 1')
    return
  endif

  call self._shrink_to(self.get_last(), v:none, 0)
  call self.recolor()
  call self.refreshInfo()
  call self._check_queue()

  if coquille#get_buffer_config(s:auto_move, 0)
    call self.move(self.get_last())
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
  if !self.is_initiated()
    return
  endif

  if s:pos_le(self.get_last(), a:pos)
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
  if !self.is_initiated()
    return
  endif

  let content = self.getContent()
  let last = self.get_last()

  let next_endpos = coqlang#nextSentencePos(content, last)

  if next_endpos is v:null
    return
  endif

  call self._shrink_to(last)

  if len(self.queue) == 0
    let self.info_message = []
  endif

  let last_inclusive = [last[0], last[1] - 1]

  if s:pos_le(a:pos, last_inclusive)
    return
  endif

  while s:pos_lt(last_inclusive, a:pos)
    let last = coqlang#nextSentencePos(content, last)

    if last is v:null
      break
    endif

    exe s:assert('last[1] >= 1')
    let last_inclusive = [last[0], last[1] - 1]

    call add(self.queue, last)
  endwhile

  if !a:ceil && a:pos != last_inclusive
    call remove(self.queue, -1)
  endif

  call self.recolor()
  call self.refreshInfo()
  call self._check_queue()
endfunction
" }}}

" coq_to_pos {{{
function! s:IDE.coq_to_pos(pos, ceil=0) abort
  if !self.is_initiated()
    return
  endif

  let last = self.get_last()

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
  let pos = [curpos[0] - 1, curpos[1] - 1]

  let ceil = 0

  if a:ceil isnot v:null
    ceil = a:ceil
  else
    let ceil = coquille#get_buffer_config(s:cursor_ceiling, 0)
  endif

  call self.coq_to_pos(pos, ceil)
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
