" register this buffer as a coq file
call coqpit#register()
call coqpit#color#defineColorScheme()

augroup coqpit_colorscheme
  autocmd!
  autocmd ColorScheme * :call coqpit#color#defineColorScheme()
augroup END
