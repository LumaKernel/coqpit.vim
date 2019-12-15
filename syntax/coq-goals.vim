" Language:     Coq-goals
" Filenames:    Goals
" Original:  Laurent Georget <laurent@lgeorget.eu>
" License:     public domain

if exists("b:current_syntax")
  finish
endif

runtime! syntax/coq.vim

" Coq is case sensitive.
syn case match

" Number of goals
syn match   coqNumberGoals       '\d\+ subgoals\?' nextgroup=coqGoal

" Hypothesis
syn region  coqHypothesisBlock  contains=coqHypothesis start="^[_[:alpha:]][_'[:alnum:]]*\s*:" end="^$" keepend
syn region  coqHypothesis       contained contains=coqHypothesisBody matchgroup=coqIdent start="^[_[:alpha:]][_'[:alnum:]]*" matchgroup=NONE end="^\S"me=e-1
syn region  coqHypothesisBody   contained contains=@coqTerm matchgroup=coqVernacPunctuation start=":" matchgroup=NONE end="^\S"me=e-1

" Separator
syn match   coqGoalNumber       contained "(\s*\d\+\s*\/\s*\d\+\s*)"
syn region  coqGoalSep          matchgroup=coqGoalLine start='^=\+' matchgroup=NONE end='^$' contains=coqGoalSepNumber
syn region  coqGoalSepNumber    matchgroup=coqGoalNumber start="(\s*\d\+\s*\/\s*\d\+\s*)" matchgroup=NONE end="^$" contains=@coqTerm

" TODO
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


let b:current_syntax = "coq-goals"
