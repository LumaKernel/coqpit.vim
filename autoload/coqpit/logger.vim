" This is for easing debugging

" @type string[]
let s:log_list = []
let s:last_executed = -1
let s:last_checked = -1

function! s:is_debug() abort
  return !empty(get(g:, 'coqpit_debug', 0))
endfunction

" Usage:
"   let s:log = function('coqpit#logger#log')
"   exe s:log("something to log", "and more")
function! coqpit#logger#log(...) abort
  if !s:is_debug()
    return ""
  endif

  let str_expr_list = [s:descriptor()]
  if a:0 is# 0
    call add(str_expr_list, s:build_str("<log is empty>"))
  elseif a:0 is# 1
    call add(str_expr_list, s:build_str(s:obj_to_str(a:1)))
  else
    for i in range(a:0)
      call add(str_expr_list, s:build_str("\n"))
      call add(str_expr_list, s:build_str(s:obj_to_str(a:000[i])))
    endfor
  endif
  call add(str_expr_list, s:build_str("\n"))
  return printf("call coqpit#logger#_log(%s)", join(str_expr_list, '.'))
endfunction

function! coqpit#logger#_log(str) abort
  let s:log_list += split(a:str, '\n')
endfunction


function! coqpit#logger#get_log() abort
  return copy(s:log_list)
endfunction
function! coqpit#logger#clear_log() abort
  let s:log_list = []
endfunction

function! s:descriptor() abort
  return '(expand("<sfile>:p") . ": line " . expand("<sflnum>")) . " : "'
endfunction

function! s:build_str(str) abort
  return printf("(%s)", string(a:str))
endfunction

function! s:obj_to_str(obj) abort
  if type(a:obj) is# v:t_dict
    if has_key(a:obj, 'toString') && type(a:obj.toString) is# v:t_func
      try
        return a:obj.toString()
      catch
      endtry
    endif
  endif
  try
    return string(a:obj)
  catch
    return "<object unexpressiable in string>"
  endtry
endfunction
