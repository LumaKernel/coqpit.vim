
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

" CoqTop only supports &lt; , &gt; , &quot; , &apos , &amp;
" though &#34; euqals to &quot;
function! coquille#xml#escape(str) abort
  return a:str
    \->substitute('&', '\&amp;', 'g')
    \->substitute('<', '\&lt;', 'g')
    \->substitute('>', '\&gt;', 'g')
    \->substitute('"', '\&quot;', 'g')
    \->substitute("'", '\&apos;', 'g')
endfunction

function! coquille#xml#unescape(str) abort
  return a:str
    \->substitute('\c&lt;', '<', 'g')
    \->substitute('\c&gt;', '>', 'g')
    \->substitute('\c&nbsp;', ' ', 'g')
    \->substitute('\c&apos;', "'", 'g')
    \->substitute('\c&quot;', '"', 'g')
    \->substitute('\c&amp;', '\&', 'g')
endfunction

