" register this buffer as a coq file
call coquille#register()

augroup coquille_colorscheme
  autocmd!
  autocmd ColorScheme * :call coquille#color#defineColorScheme()
augroup END


