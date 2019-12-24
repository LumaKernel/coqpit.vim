
function! coquille#test#runTest()
  call coqlang#Test()
  call coquille#color#Test()
  call coquille#IDE#Test()
  call coquille#annotate#Test()
endfunction

