
function! coquille#xml#2str(xml)
  if type(a:xml) == v:t_string
    return coquille#xml#unescape(a:xml)
  endif

  let res = ''
  for el in a:xml.child
    let res ..= coquille#xml#2str(el)
  endfor

  return res
endfunction

function! coquille#xml#unescape(str) abort
  return a:str
    \->substitute('&nbsp;', ' ', 'g')
    \->substitute('&apos;', "'", 'g')
endfunction

