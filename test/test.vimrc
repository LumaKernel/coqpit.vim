" this file is for all vim versions
try
  so <sfile>:h/test.vim
catch /.*/
  silent! !echo Unexpected Error happened!
  silent! exe '!echo ' .. shellescape('Exception: ' .. string(v:exception), 1)
  silent! exe '!echo ' .. shellescape('Throwpoint: ' .. string(v:throwpoint), 1)
  cq!
endtry
