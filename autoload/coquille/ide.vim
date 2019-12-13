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

  let self.CoqTopDriver = coquille#coqtop#makeInstance(a:args)
  call self.CoqTopDriver.setGoalCallback(self._goalCallback)
  call self.CoqTopDriver.setInfoCallback(self._infoCallback)

  return self
endfunction


" -- private

function! s:IDE._goalCallback(xml) abort
endfunction

function! s:IDE._infoCallback(level, msg, payload) abort
  " TODO coloring
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


function! s:IDE.recolor()
  for id in self.colored
    call matchdelete(id)
  endfor

  let self.colored = []
  let cursor = self.getCursor()

  let self.colored += s:matchaddrange(self.maxlen(), "SentToCoq", [[0, 0], cursor])
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

function! s:matchaddrange(maxlen, group, range, priority=10, id=-1, dict={})
  let [spos, epos] = a:range
  let [sline, scol] = spos
  let [eline, ecol] = epos

  call assert_true(spos[0] < epos[0] || (spos[0] == epos[0] && spos[1] <= epos[1]))
  if spos == epos
    return []
  endif

  echom a:range
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

function! s:matchaddlines(group, lines, priority=10, id=-1, dict={})
  let ids = []
  echom a:lines
  for line in a:lines
    call add(ids, matchaddpos(a:group, [[line + 1]], a:priority, a:id, a:dict))
  endfor
  return ids
endfunction


" export

function! coquille#ide#makeInstance(bufnr, args = []) abort
  return s:IDE.new(a:bufnr, a:args)
endfunction

