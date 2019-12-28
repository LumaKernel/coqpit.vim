" Language:     Coq-goals
" Filenames:    Goals
" Original:  Laurent Georget <laurent@lgeorget.eu>
" License:     public domain

if exists('b:current_syntax')
  finish
endif

runtime! syntax/coq.vim

" Coq is case sensitive.
syn case match

" By default, treat lines as coq term.
syn match  coqGoalTerm          /^.*$/ contains=@coqTerm

" first line
syn match  coqGoalDescription   /\%1l/
" last line
syn match  coqGoalDescription   /^.*\%$/

" Number of goals
syn match   coqNumberGoals       '\d\+ subgoals\?' nextgroup=coqGoal

" Hypothesis
syn region  coqHypothesisBlock  contains=coqHypothesis start="^\K[[:keyword:]']*\_s*\%(\_s*,\_s*\K[[:keyword:]']*\_s*\)\_s*:" end=".$" keepend
syn region  coqHypothesis       contained contains=coqHypothesisBody,coqHypothesis matchgroup=coqIdent start="\K[[:keyword:]']*" matchgroup=NONE end=".$" keepend
syn region  coqHypothesisBody   contained contains=@coqTerm matchgroup=coqVernacPunctuation start=":" matchgroup=NONE end=".$" keepend

" Separator
syn match   coqGoalNumber       contained "(\s*\d\+\s*\/\s*\d\+\s*)"
" syn region  coqGoalSep          matchgroup=coqGoalLine start='^_\+' matchgroup=NONE end='^$' contains=coqGoalSepNumber
syn match  coqGoalLine          /^_.*$/ contains=coqGoalSepNumber
syn region  coqGoalSepNumber    matchgroup=coqGoalNumber start="(\s*\d\+\s*\/\s*\d\+\s*)" matchgroup=NONE end=".$" contains=@coqTerm

" Synchronization
syn sync minlines=50
syn sync maxlines=500

" TERMS AND TYPES
hi def link coqTerm                      Type
hi def link coqKwd             coqTerm
hi def link coqTermPunctuation coqTerm

" WORK LEFT
hi def link coqNumberGoals               Todo
hi def link coqGoalLine                  Todo

" GOAL IDENTIFIER
hi def link coqGoalNumber                Underlined


let b:current_syntax = 'coq-goals'
