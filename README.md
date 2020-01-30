# Coquille

![](https://github.com/lumakernel/coquille/workflows/GitHub%20Actions%20CI/badge.svg)

Coquille brings the interactivity and asynchronous of CoqIDE into Vim and Neovim.

This repository is fork of [the-lambda-church/coquille](https://github.com/the-lambda-church/coquille).


## Dependencies

Only Vim ( or Neovim ) and [Coq](https://github.com/coq/coq/releases).

- Vim 8.0 or above or Neovim"TODO version" ( `+job/has('nvim')`, `+lambda`, etc; recommend you `+huge` )
- Coq 8.6 or above. Checked versions below.
  - Coq8.5pl3
  - Coq8.6
  - Coq8.7
  - [Coq8.9](https://github.com/coq/coq/releases/tag/V8.9.1)
  - [Coq8.10](https://github.com/coq/coq/releases/tag/V8.10.2)
  - Coq8.11 (beta)
  - Recomended to use newer and more stable version.


## Installation

Please clone this repository to your vim `runtimepath` or if you use plugin manager like [dein.vim](https://github.com/Shougo/dein.vim), add `LumaKernel/coquille` repository.

### Example for [dein.vim](https://github.com/Shougo/dein.vim)

Add following to your toml file.

```toml
[[plugins]]
repo = "LumaKernel/coquille"
```

## Specifying coq executable

By default, coq will check the command `coqidetop`
followed by checking `coqtop`.

However, if you want to use a specific version or executable,
set variable `g:coquille_coq_executable` in your `.vimrc` .

Typically, you should specify `{CoqInstallPath}/bin/coqidetop`
or `{CoqInstallPath}/bin/coqtop` for old versions.


To learn more flexible options, see `:help coquille-options` .


## Getting started


1. Open coq file that typically ends with `.v`
2. Run `:CoqLaunch` ( or write `let g:coquille_auto_launch=1` in your `.vimrc` )
3. Opening Infos/Goals buffers automatically.

Now, these commands can be used.

- `:CoqNext`
  + Forward one command.
- `:CoqBack`
  + Drop last command.
- `:CoqToCursor`
  + Forward to cursor.
- `:CoqToLast`
  + Forward to end of file.
- And other commands. See `:help coquille-commands` .

## Mapping Examples


```vim
function! MyCoqMaps()
  nnoremap <silent> <C-C>        :CoqLaunch<CR>
  nnoremap <silent> <Leader>j    :CoqNext<CR>
  nnoremap <silent> <Leader>k    :CoqBack<CR>
  nnoremap <silent> <Leader>l    :CoqToCursor<CR>
  nnoremap <silent> <Leader>G    :CoqToLast<CR>
  nnoremap <silent> <Leader>g    :CoqRerun<CR>
  nnoremap <silent> <Leader>t    :MoveToTop<CR>
  nnoremap <silent> <Leader><F5> :CoqRefresh<CR>

  nnoremap <Leader>compute :CoqQuery Compute .<Left>
  nnoremap <Leader>print :CoqQuery Print .<Left>
  nnoremap <Leader>check :CoqQuery Check .<Left>
  nnoremap <Leader>se :CoqQuery Search ().<Left><Left>
endfunction

augroup my_coq
  au!
  au FileType coq :call MyCoqMaps()
augroup END
```


Recommended to define non-buffer local because these commands can be also used
from Infos/Goals buffers too. ( If not using `coquille_one_window=1`. )


## Configuration Highlight Colors

Coquille will set the highligh colors automatically from backgrond color of your color scheme if you are using gui Vim.

- CoqChecked
- CoqCheckedAxiom
- CoqQueued
- CoqMarkedWarn
- CoqCheckedWarn
- CoqMarkedError
- CoqCheckedError

Needless to say, literally. Please check by yourself while using.
For more information, see `:help coquille-highlight-groups`

### Example for highlight config

This is example assuming for cterm with `hybrid` color scheme.

```vim
hi CoqChecked      ctermbg=17
hi CoqCheckedAxiom ctermbg=58
hi CoqQueued       ctermbg=22
hi CoqMarkedWarn   ctermbg=64
hi CoqCheckedWarn  ctermbg=64
hi CoqMarkedError  ctermbg=160
hi CoqCheckedError ctermbg=160
```

## Customize window locations

1. Make your own Rearrange command.
2. In that command,
  - Use `b:coquille_goal_bufnr` and `b:coquille_info_bufnr`
    to control Goals/Infos buffers.
  - If you are using `coquille_one_window=1` option,
    use tablocal ( prefexed `t:` ) ones.
3. Make your own Launch command.
4. In that command,
  1. Run `:CoqLaunch`
  2. Run your own Rearrange command.

Use your command or replace with original ones.

For concrete example, see `:help coquille-customize-window-example` .


## F.A.Q.

### Messed up Infos and Goals windows!

To reset all __Infos__ and __Goals__ windows,

1. `:bdelete` all not needed `[Goals]` and `[Infos]` buffers by yourself.
  - or use `:CoqStopAll` command [or `:call coquille#stop_all()`]
2. Run `:CoqRearrange` [or `:call coquille#reset_panels(1)`]
  - on each window attached by coq file if you open multiple buffers and configure `one_window` is '0'
  - on each tab if you open multiple tabs

Or, reboot your Vim.


### I want to pass the path in Windows MSYS2.

Like this.

```vim
let g:coquille_coq_executable = '/c/Coq8.10/bin/coqidetop'
```


## Screenshoots

![Coquille use at win32unix with multiple buffers](https://user-images.githubusercontent.com/29811106/71498345-59386280-289f-11ea-9018-2babde26ca82.png)

![Coquille use at win32](https://user-images.githubusercontent.com/29811106/71498699-aff26c00-28a0-11ea-97c9-ea165542ccd8.png)

![with highlight\_style\_checked tail](https://user-images.githubusercontent.com/29811106/73458139-26aae980-43b8-11ea-9bba-2ec95521c1f8.png)
This is with `g:coquille_highlight_style_checked='tail'`.

## Known Issues

- With configure `g:coquille_update_status_always` to `0`, [coq issues #9680](https://github.com/coq/coq/issues/9680) happens also in this plugin.
  - I recommend you NOT change this option. By default, working fine.
- If you use too many memory, coquille fails with like an error message `Error: Out of memory`.
  - Refrain from using in unstable environment.


## License

[ISC License](https://www.isc.org/licenses/)


## Thanks

- [the-lambda-church/coquille](https://github.com/the-lambda-church/coquille)
  - Original repository I forked and from which I use the name.
- [coq syntax on vim.org](http://www.vim.org/scripts/script.php?script_id=2063)
- [coq indent on vim.org](http://www.vim.org/scripts/script.php?script_id=2079)
- [vital.vim](https://github.com/vim-jp/vital.vim)
- [vital-power-assert](https://github.com/haya14busa/vital-power-assert)

