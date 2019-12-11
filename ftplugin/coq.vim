call coquille#Register()

if !exists(":")
  command CoqRearrange :only<CR>:vs<CR><C-w>l:b Goals<CR>:sp<CR><C-w>j:b Infos<CR><C-w>h
endif

