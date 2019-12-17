" ============
" Coquille IDE
" ============

let s:PowerAssert = vital#vital#import('Vim.PowerAssert')
let s:assert = s:PowerAssert.assert

let s:IDE = {}

function! s:IDE.new(bufnr, args = []) abort
  " TODO : Use argss

  let self.handling_bufnr = a:bufnr

  let self.GoalBuffers = []
  let self.InfoBuffers = []

  let self.sentencePosList = [[0, 0]]
  let self.state_id_list = []
  let self.colored = []
  let self.hls = []

  let self.goal_message = []
  let self.info_message = []

  let self.state_id_to_range = {}

  function! s:after_init(state_id) abort closure
    call add(self.state_id_list, a:state_id)
    let self.state_id_to_range[a:state_id] = [[0, 0], [0, 0]]
  endfunction

  let self.coqtop_handler = coquille#coqtop#makeInstance(a:args, funcref('s:after_init', self))
  call self.coqtop_handler.set_info_callback(self._infoCallback)

  return self
endfunction


" -- private

" -- -- callbacks to CoqTopHandler operations {{{

function! s:IDE._goalCallback(goals) abort
  let goal_message = []
  if a:goals is v:null
  else
    if len(a:goals) == 0
      let goal_message = ["No goals."]
    else
      let goal_message = a:goals
    endif
  endif

  call self.refreshGoal()
endfunction

function! s:IDE._infoCallback(state_id, level, msg, loc) abort
  exe s:assert('has_key(self.state_id_to_range, a:state_id)')
  let [spos, epos] = self.state_id_to_range[a:state_id]

  let self.info_message += [a:msg]

  if a:loc isnot v:null
    let [start, end] = a:loc
    let mes_range = [self.steps(spos, start, 1), self.steps(spos, end, 1)]

    exe s:assert('mes_range[0] isnot v:null')
    exe s:assert('mes_range[1] isnot v:null')

    if a:level == "error"
      call add(self.hls, ["CoqMarkedError", mes_range, 30])
      call self._shrinkTo(epos)
    elseif a:level == "warning"
      call add(self.hls, ["CoqCheckedWarn", mes_range, 20])
    elseif a:level == "info"
    elseif a:level == ""
    else
      throw "Error: Unkown message level"
    endif
  else
  endif

  call self.recolor()
  call self.refreshInfo()
endfunction

" }}}

function! s:IDE._shrinkTo(pos) abort
  while len(self.sentencePosList) > 1
        \ && sort([[a:pos, 0], [self.sentencePosList[-1], 1]])[0][1] == 0
    call remove(self.sentencePosList, -1)
  endwhile

  silent! unlet self.state_id_list[len(self.sentencePosList):-1]
endfunction


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


" Returns last position which is not sent.
"
" return Pos
function! s:IDE.getCursor() abort
  return self.sentencePosList[-1]
endfunction


function! s:IDE.recolor() abort
  for id in self.colored
    call matchdelete(id)
  endfor

  if len(self.state_id_list)
    let self.colored = []
    let cursor = self.getCursor()
    let last = self.state_id_to_range[self.state_id_list[-1]][1]
    let maxlen = self.maxlen()
    ECHO last

    let self.colored += s:matchaddrange(maxlen, "CoqChecked", [[0, 0], last])
    let self.colored += s:matchaddrange(maxlen, "CoqQueued", [last, cursor])

    for [group, range, priority] in self.hls
      let self.colored += s:matchaddrange(maxlen, group, range, priority)
    endfor
  endif
endfunction

function! s:IDE.steps(pos, num, newline_as_one = 0) abort
  let content = self.getContent()
  let now = 0
  let [line, col] = a:pos
  let linenum = len(content)

  while line < linenum
    let newcol = col + a:num - now
    if newcol < len(content[line]) + a:newline_as_one
      return [line, newcol]
    else
      let now += max([len(content[line]) + a:newline_as_one - col, 0])

      let line += 1
      let col = 0
    endif
  endwhile
  return v:null
endfunction


" -- -- callback for sending sentence {{{

function! s:IDE._makeResultCallback(range) abort
  function! s:_resultCallback(state_id, is_err, msg, err_loc) abort closure
    let [spos, epos] = a:range
    let refresh = self.coqtop_handler.isQueueEmpty()

    if a:is_err
      call self._shrinkTo(epos)
      call self.coqtop_handler.clearSentenceQueue()
      call self.coqtop_handler.refreshGoalInfo()

      if a:err_loc isnot v:null
        let [start, end] = a:err_loc
        let mes_range = [self.steps(spos, start, 1), self.steps(spos, end, 1)]
        call add(self.hls, ["CoqMarkedError", mes_range, 30])
      endif

      if a:msg != ''
        let self.info_message += [a:msg]
      endif
    else
      call add(self.state_id_list, a:state_id)
      let self.state_id_to_range[a:state_id] = a:range
    endif

    if refresh
      call self.coqtop_handler.refreshGoalInfo()
    endif

    call self.recolor()
    call self.refreshInfo()
  endfunction

  return funcref('s:_resultCallback', self)
endfunction
" }}}


" -- -- cursor move (cursor means last position which was not sent)

" cursorNext {{{
function! s:IDE.cursorNext() abort
  let content = self.getContent()
  let cursor = self.getCursor()
  let sentence_range = coqlang#nextSentenceRange(content, cursor)

  let self.info_message = []
  
  if sentence_range is v:null
    return
  endif

  call add(self.sentencePosList, sentence_range[1])

  let sentence = join(self.getContent(sentence_range), "\n")

  call self.coqtop_handler.queueSentence(sentence, self._makeResultCallback(sentence_range))

  if exists("g:coquille_auto_move") && g:coquille_auto_move is 1
    call self.move(sentence_range[1])
  endif

  call self.recolor()
endfunction  " }}}

" cursorBack {{{
function! s:IDE.cursorBack() abort
  if len(self.sentencePosList) == 1
    return
  endif
  exe s:assert('len(self.sentencePosList) > 1')

  ECHO self.state_id_list
  ECHO self.sentencePosList

  let self.info_message = []

  let removed = remove(self.sentencePosList, -1)
  silent! unlet self.state_id_list[len(self.sentencePosList):-1]

  " think `else` as possibility, `queued but not sent`
  if len(self.state_id_list) && len(self.state_id_list) == len(self.sentencePosList)
    let new_state_id = self.state_id_list[-1]
    call self.coqtop_handler.editAt(new_state_id, self._after_edit_at)
  endif

  if exists("g:coquille_auto_move") && g:coquille_auto_move is 1
    call self.move(removed)
  endif
  call self.coqtop_handler.refreshGoalInfo()

  call self.recolor()
endfunction
function! s:IDE._after_edit_at(is_err, state_id) abort
  if a:is_err
    " TODO: restart ? shrink to valid sate_id ?
    echoerr "[Coquille IDE] internal error."
  endif
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



" internal

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



" export

function! coquille#ide#makeInstance(...) abort
  return call(s:IDE.new, a:000)
endfunction
