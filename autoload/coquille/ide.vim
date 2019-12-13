" ============
" Coquille IDE 
" ============

let s:IDE = {}

function! s:IDE.new(bufnr, args = []) abort
  " TODO : Use argss

  let self.handling_bufnr = bufnr

  let self.GoalBuffers = []
  let self.InfoBuffers = []

  let self.sentencePosList = []

  let self.CoqTopDriver = coquille#coqtop#makeInstance(args)
  call self.CoqTopDriver.setGoalCallback(self._goalCallback)
  call self.CoqTopDriver.setInfoCallback(self._infoCallback)

  return self
endfunction


" -- private

function! s:IDE._goalCallback(xml) abort
endfunction

function! s:IDE._infoCallback(level, msg) abort
endfunction


" -- public

function! s:IDE.addGoalBuffer(bufnr) abort
  call add(self.GoalBuffers, bufnr)
endfunction

function! s:IDE.addInfoBuffer(bufnr) abort
  call add(self.InfoBuffers, bufnr)
endfunction

" return [string]
function! s:IDE.getContent() abort
  return getbufline(self.handling_bufnr, 1, '$')
endfunction

" Returns last position which is not sent.
" return Pos
function! s:IDE.getCursor() abort
  if len(self.sentencePosList) == 0
    return [0, 0]
  endif
  return self.sentencePosList[-1]
endfunction



" -- -- cursor move (cursor means last position which was not sent)

function! s:IDE.cursorNext() abort
  let content = self.getContent()
  let cursor = self.getCursor()
  let sentense_range = coquille#coqlang#getNextSentenceRange(content, cursor)
  
  if type(sentense_range) == type(v:null)
    return
  endif

  self.CoqTopDriver.queueSentence(sentence)

  if exists("g:coquille_auto_move") && g:coquille_auto_move == 1
    self.move(sentense_range[0])
  endif
endfunction


" -- -- move (vim editor's cursor move)

function! s:IDE.focusing() abort
  return self.handling_bufnr == bufnr('%')
endfunction

function! s:IDE.move(pos) abort
  if focusing()
    let [line, col] = pos
    call cursor(line, col + 1)
  endif
endfunction



" internal


" -- test
if 1
endif


" export

function! coquille#ide#makeInstance(bufnr, args = []) abort
  return s:IDE.new(bufnr, args)
endfunction

