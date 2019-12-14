" ============
" Coquille IDE
" ============

let s:IDE = {}

function! s:IDE.new(bufnr, args = []) abort
  " TODO : Use argss

  let self.handling_bufnr = a:bufnr

  let self.GoalBuffers = []
  let self.InfoBuffers = []

  let self.sentencePosList = []
  let self.colored = []
  let self.hls = []

  let self.CoqTopDriver = coquille#coqtop#makeInstance(a:args)

  " We should bind.
  call self.CoqTopDriver.setGoalCallback(function(self._goalCallback, self))
  call self.CoqTopDriver.setInfoCallback(function(self._infoCallback, self))

  return self
endfunction


" -- private

function! s:IDE._goalCallback(xml) abort
  " TODO
  echom xml
endfunction

function! s:IDE._infoCallback(level, msg, loc, payload) abort
  let [spos, epos] = a:payload["range"]

  if type(a:loc) != v:t_none
    let [start, end] = a:loc
    let mes_range = [self.steps(spos, start), self.steps(spos, end)]
    if a:level == "error"
      call add(self.hls, ["CoqError", mes_range, 30])
      call self._shrinkTo(epos)
    elseif a:level == "warning"
      call add(self.hls, ["CoqWarn", mes_range, 20])
    elseif a:level == "info"
    elseif a:level == ""
    else
      throw "Error: Unkown message level"
    endif
  endif

  call self.recolor()
  let self.hls = []
endfunction

function! s:IDE._shrinkTo(pos) abort
  while len(self.sentencePosList)
        \ && sort([[a:pos, 0], [self.sentencePosList[-1], 1]])[0][1] == 0
    call remove(self.sentencePosList, -1)
  endwhile
endfunction


" -- public

function! s:IDE.addGoalBuffer(bufnr) abort
  call add(self.GoalBuffers, a:bufnr)
endfunction

function! s:IDE.addInfoBuffer(bufnr) abort
  call add(self.InfoBuffers, a:bufnr)
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
  return max(map(self.getContent(), { a -> len(a) }))
endfunction


" Returns last position which is not sent.
" return Pos
function! s:IDE.getCursor() abort
  if len(self.sentencePosList) == 0
    return [0, 0]
  endif
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

function! s:IDE.steps(pos, num) abort
  let content = self.getContent()
  let now = 0
  let [line, col] = a:pos
  let linenum = len(content)

  while now < a:num && line < linenum
    let newcol = col + a:num - now
    if newcol < len(content[line])
      return [line, newcol]
    else
      let now += max([len(content[line]) - col, 0])

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
  
  if type(sentence_range) == v:t_none
    return
  endif

  call add(self.sentencePosList, sentence_range[1])

  let sentence = join(self.getContent(sentence_range), "\n")

  call self.CoqTopDriver.queueSentence(sentence, {"range": sentence_range})

  if exists("g:coquille_auto_move") && g:coquille_auto_move == 1
    self.move(sentence_range[0])
  endif

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
  let [spos, epos] = a:range
  let [sline, scol] = spos
  let [eline, ecol] = epos

  call assert_true(spos[0] < epos[0] || (spos[0] == epos[0] && spos[1] <= epos[1]))
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

