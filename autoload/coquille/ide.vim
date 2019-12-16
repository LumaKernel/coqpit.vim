" ============
" Coquille IDE
" ============

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

  let self.CoqTopDriver = coquille#coqtop#makeInstance(a:args)

  " We should bind.
  call self.CoqTopDriver.setGoalCallback(self._goalCallback)
  call self.CoqTopDriver.setInfoCallback(self._infoCallback)
  call self.CoqTopDriver.setResultCallback(self._resultCallback)
  call self.CoqTopDriver.setInitiatedCallback(self._initiatedCallback)

  return self
endfunction


" -- private

" -- -- callbacks to CoqTopHandler operations {{{

function! s:IDE._initiatedCallback(state_id, _payload) abort
  call add(self.state_id_list, a:state_id)
endfunc

function! s:IDE._goalCallback(goals, _payload) abort
  let goal_message = []
  if type(a:goals) == v:t_none
  else
    if len(a:goals) == 0
      let goal_message = ["No goals."]
    else
      let goal_message = a:goals
    endif
  endif

  call self.refreshGoal()
endfunction

function! s:IDE._infoCallback(state_id, level, msg, loc, payload) abort
  call add(self.state_id_list, a:state_id)
  let [spos, epos] = self.state_id_to_range[a:state_id]

  if type(a:loc) != v:t_none
    let [start, end] = a:loc
    let mes_range = [self.steps(spos, start, 1), self.steps(spos, end - 1, 1)]

    call coquille#assert('type(mes_range[0]) != v:t_none')
    call coquille#assert('type(mes_range[1]) != v:t_none')

    if type(mes_range[0]) == v:t_none || type(mes_range[1]) == v:t_none
      echom [spos, start]
      echoerr mes_range
      throw "[Coquille IDE] internal error."
    endif

    if a:level == "error"
      call add(self.hls, ["CoqError", mes_range, 30])
      call self._shrinkTo(epos)
      let self.info_message += [a:msg]
    elseif a:level == "warning"
      call add(self.hls, ["CoqWarn", mes_range, 20])
      let self.info_message += [a:msg]
    elseif a:level == "info"
      let self.info_message += [a:msg]
    elseif a:level == ""
    else
      throw "Error: Unkown message level"
    endif
  endif

  call self.recolor()
  call self.refreshInfo()
  let self.hls = []
endfunction

function! s:IDE._resultCallback(state_id, is_err, msg, err_loc, payload) abort
  let range = a:payload["range"]
  let [spos, epos] = range
  " let refresh = a:payload["refresh"]
  let refresh = self.CoqTopDriver.isQueueEmpty()

  if a:is_err
    call self._shrinkTo(epos)
    call self.CoqTopDriver.clearSentenceQueue()
    " call self.CoqTopDriver.refreshGoalInfo(a:payload)

    echom "hi"
    echom [a:is_err, a:msg, a:err_loc, a:payload]

    if type(a:err_loc) != v:t_none
      let [start, end] = a:err_loc
      let mes_range = [self.steps(spos, start, 1), self.steps(spos, end - 1, 1)]
      call add(self.hls, ["CoqError", mes_range, 30])
    endif

    echom "hi2"

    if a:msg != ''
      let self.info_message += [a:msg]
    endif
  else
    let self.state_id_to_range[a:state_id] = range
  endif

  if refresh
    call self.CoqTopDriver.refreshGoalInfo(a:payload)
  endif

  call self.recolor()
  call self.refreshInfo()
  let self.hls = []
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
  if type(a:range) == v:t_none
    return getbufline(self.handling_bufnr, 1, '$')
  endif

  let [spos, epos] = a:range
  let [sline, scol] = spos
  let [eline, ecol] = epos

  call assert_true(spos[0] < epos[0] || (spos[0] == epos[0] && spos[1] <= epos[1]))

  let lines = getbufline(self.handling_bufnr, sline + 1, eline + 2)

  let lines[eline-sline] = lines[eline-sline][:ecol]
  let lines[0] = lines[0][scol:]

  return lines
endfunction

function! s:IDE.maxlen() abort
  return max(map(self.getContent(), 'len(v:val)'))
endfunction


" Returns last position which is not sent.
" return Pos
function! s:IDE.getCursor() abort
  return self.sentencePosList[-1]
endfunction


function! s:IDE.recolor() abort
  for id in self.colored
    call matchdelete(id)
  endfor

  let self.colored = []
  let cursor = self.getCursor()
  let maxlen = self.maxlen()

  let self.colored += s:matchaddrange(maxlen, "SentToCoq", [[0, 0], cursor])

  for [group, range, priority] in self.hls
    let self.colored += s:matchaddrange(maxlen, group, range, priority)
  endfor
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


" -- -- cursor move (cursor means last position which was not sent)

function! s:IDE.cursorNext() abort
  let content = self.getContent()
  let cursor = self.getCursor()
  let sentence_range = coqlang#nextSentenceRange(content, cursor)

  let self.info_message = []
  
  if type(sentence_range) == v:t_none
    return
  endif

  call add(self.sentencePosList, sentence_range[1])

  let sentence = join(self.getContent(sentence_range), "\n")

  let payload = {'range': sentence_range, 'refresh': 1}
  call self.CoqTopDriver.queueSentence(sentence, payload)

  if exists("g:coquille_auto_move") && g:coquille_auto_move == 1
    self.move(sentence_range[1])
  endif

  call self.recolor()
endfunction

function! s:IDE.cursorBack() abort
  if len(self.sentencePosList) == 1
    return
  endif

  let self.info_message = []

  let removed = remove(self.sentencePosList, -1)
  silent! unlet self.state_id_list[len(self.sentencePosList):-1]

  " think `else` as possibility, `queued but not sent`
  if len(self.state_id_list) && len(self.state_id_list) == len(self.sentencePosList)
    let new_state_id = self.state_id_list[-1]
    call self.CoqTopDriver.editAt(new_state_id)
  endif

  if exists("g:coquille_auto_move") && g:coquille_auto_move == 1
    self.move(sentence_range[1])
  endif
  call self.CoqTopDriver.refreshGoalInfo()

  call self.recolor()
endfunction


" -- -- move (vim editor's cursor move)

function! s:IDE.focusing() abort
  return self.handling_bufnr == bufnr('%')
endfunction

function! s:IDE.move(pos) abort
  if focusing()
    let [line, col] = a:pos
    call cursor(line, col + 1)
  endif
endfunction


" internal

function! s:matchaddrange(maxlen, group, range, priority=10, id=-1, dict={}) abort
  echom [a:range]
  let [spos, epos] = a:range
  let [sline, scol] = spos
  let [eline, ecol] = epos

  if spos == epos
    return []
  endif

  let ids = []
  if sline == eline
    call add(ids, matchaddpos(a:group, [[sline + 1, scol + 1, ecol - scol + 1]], a:priority, a:id, a:dict))
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

function! coquille#ide#makeInstance(bufnr, args = []) abort
  return s:IDE.new(a:bufnr, a:args)
endfunction

