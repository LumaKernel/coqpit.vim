" Language:    Coq-infos
" Filenames:   Infos
" Original:  Laurent Georget <laurent@lgeorget.eu>
" License:     public domain

if exists("b:current_syntax")
  finish
endif

runtime! syntax/coq.vim

" Coq is case sensitive.
syn case match

" Definitions
syn region coqDefName2       contained contains=coqDefBinder,coqDefType,coqDefContents1 matchgroup=coqIdent start="[_[:alpha:]][_'[:alnum:]]*" matchgroup=NONE end="\.\_s" end=":="
syn region coqDefContents2     contained contains=@coqTerm matchgroup=coqVernacPunctuation start="=" matchgroup=NONE end="^$"

syn region coqDefNameHidden     matchgroup=coqComment start="\*\*\* \[" matchgroup=coqComment end="\]" contains=@coqTerm,coqDefContents3
syn region coqDefContents3     contained contains=@coqTerm matchgroup=coqVernacPunctuation start=":" end="]"me=e-1

" Modules
syn keyword coqModuleEnd  contained End
" syn region  coqStructDef  contained contains=coqStruct matchgroup=coqVernacPunctuation start=":=" end="End"
" syn region  coqStruct     contained contains=coqIdent,coqDef,coqThm,coqDec,coqInd matchgroup=coqTopLevel start="\<Struct\>" end="End"

" Sections
syn match coqSectionDelimiter  "^ >>>>>>>" nextgroup=coqSectionDecl skipwhite skipnl
syn match coqSectionDecl       contained "Section" nextgroup=coqSectionName skipwhite skipnl
syn match coqSectionName       contained "[_[:alpha:]][_'[:alnum:]]*"

" Compute
" syn region coqComputed  contains=@coqTerm matchgroup=coqVernacPunctuation start="^\s*=" matchgroup=NONE end="^$"

" Notations
" TODO : unused
" syn region coqNotationDef       contains=coqNotationString,coqNotationTerm matchgroup=coqVernacCmd start="\<Notation\>\%(\s*\<Scope\>\)\?" end="^$"
" syn region coqNotationTerm      contained matchgroup=coqVernacPunctuation start=":=" matchgroup=NONE end="\""me=e-1 end="^$"me=e-1 contains=coqNotationScope,coqNotationFormat
" syn region coqNotationScope     contained contains=@coqTerm,coqNotationFormat matchgroup=coqVernacPunctuation start=":" end="\""me=e-1 end="^$"
" syn region coqNotationFormat    contained contains=coqNotationKwd,coqString matchgroup=coqVernacPunctuation start="(" end=")"

" TODO : what ?
" syn match  coqNotationKwd    contained "default interpretation"

" Scopes
" syn region coqScopeDef       contains=coqNotationString,coqScopeTerm,coqScopeSpecification matchgroup=coqVernacCmd start="\<Scope\>" end="^$"
" syn region coqScopeTerm      contained matchgroup=coqVernacPunctuation start=":=" matchgroup=NONE end="\""me=e-1 end="^$"me=e-1 contains=@coqTerm
syn keyword coqScopeSpecification contained Delimiting key is Bound to class

" Arguments specification
syn region  coqArgumentSpecification start="^\%(For \_.\{-}:\)\?\s*Argument" end="implicit" contains=@coqTerm,coqArgumentSpecificationKeywords
syn region  coqArgumentScopeSpecification start="^\%(For \_.\{-}:\)\?\s*Argument scopes\?" end="\]" contains=@coqTerm,coqArgumentSpecificationKeywords
syn keyword coqArgumentSpecificationKeywords contained Argument Arguments is are scope scopes implicit For and maximally inserted when applied to argument arguments

" Warning and errors
syn match   coqBad               contained ".*\%(w\|W\)arnings\?"
syn match   coqVeryBad           contained ".*\%(e\|E\)rrors\?"
syn region  coqWarningMsg        matchgroup=coqBad start="^.*\%(w\|W\)arnings\?:" end="$"
syn region  coqErrorMsg          matchgroup=coqVeryBad start="^.*\%(e\|E\)rrors\?:" end="$"

" TODO
" Synchronization
syn sync minlines=50
syn sync maxlines=500


" VERNACULAR COMMANDS
hi def link coqSectionDecl       coqTopLevel
hi def link coqModuleEnd         coqTopLevel

" DEFINED OBJECTS
hi def link coqSectionName               Identifier
hi def link coqDefName                   Identifier
hi def link coqDefNameHidden             Identifier

" SPECIFICATIONS
hi def link coqArgumentSpecificationKeywords      Underlined
hi def link coqScopeSpecification                 Underlined

" WARNINGS AND ERRORS
hi def link coqBad                       WarningMsg
hi def link coqVeryBad                   ErrorMsg
hi def link coqWarningMsg                WarningMsg
hi def link coqErrorMsg                  ErrorMsg


" Comments
hi def link coqSectionDelimiter          Comment


let b:current_syntax = "coq-infos"
