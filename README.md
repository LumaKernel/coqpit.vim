# Coquille

## Goal

What this script can read is what the compiler can.

---

Coquille is a vim plugin aiming to bring the interactivity of CoqIDE into your
favorite editor.


## Dependencies

- Vim 8.1 or above ( `+job`, `+lambda`, etc; recommend you `+huge` )
- Vim `has('patch-8.1.1310')` ( default argument )
- [mattn/webapi-vim](https://github.com/mattn/webapi-vim)
  - (WIP) how about built-in
- Coq 8.5 or above. Checked versions below.
  - Coq8.5pl3
  - Coq8.7
  - Coq8.9
  - Coq8.10
  - Coq8.11 (beta)


---


## Installation

TODO : write

## Getting started

To start Coquille IDE on your Coq file, run `:CoqLaunch` ( or set `g:coquille_auto_launch=1` before loading ) which will make the
commands :

- CoqNext
- CoqBack
- CoqToCursor
- CoqRearrange

available to you.

By default Coquille forces no mapping for these commands, however two sets of
mapping are already defined and you can activate them by adding :

    " Maps Coquille commands to CoqIDE default key bindings
    au FileType coq call coquille#CoqideMapping()

or

    " Maps Coquille commands to <F2> (Undo), <F3> (Next), <F4> (ToCursor)
    au FileType coq call coquille#FNMapping()

to your `.vimrc`.

Alternatively you can, of course, define your owns.

## Mapping Examples


## Running query commands

You can run an arbitrary query command (that is `Check`, `Print`, etc.) by
calling `:Coq MyCommand foo bar baz.` and the result will be displayed in the
Infos panel.

## Configuration Highlight Colors

TODO : write

## Options

TODO : update

You can set the following variable to modify Coquille's behavior:

    g:coquille_auto_move            Set it to 1 if you want Coquille to
        (default = 0)               move your cursor to the end of the lock zone
                                    after calls to CoqNext or coqBack

## Reset messed up Infos and Goals windows

When you want to reset all __Infos__ and __Goals__ windows,

1. `:bdelete` all not needed `[Goals]` and `[Infos]` buffers by yourself.
  - or use `:CoqStopAll` command [or `:call coquille#stop_all()`]
2. Run `:CoqRearrange` [or `:call coquille#reset_panels(1)`]
  - on each window attached by coq file if you open multiple buffers and configure `one_window` is '0'
  - on each tab if you open multiple tabs

## Customize window locations

TODO : write

## Screenshoots

Because pictures are always the best sellers :

![Coquille at use](http://the-lambda-church.github.io/coquille/coquille.png)

## Known Issues

- With configure `g:coquille_update_status_always` to `0`, [coq issues #9680](https://github.com/coq/coq/issues/9680) happens also in this plugin.
  - I recommend you not changing this options. By default, working fine.
- Somehow, vim which `has('win32unix')` works faster than one which `has('win32')`
  - Not so critical.
- If you use too many memory, coquille fails with like an error message `Error: Out of memory.`.

## Thanks

TODO : write

[1]: https://github.com/tpope/vim-pathogen
[2]: https://github.com/def-lkb/vimbufsync
[3]: http://www.vim.org/scripts/script.php?script_id=2063 "coq syntax on vim.org"
[4]: http://www.vim.org/scripts/script.php?script_id=2079 "coq indent on vim.org"
[5]: https://github.com/the-lambda-church/coquille/blob/master/autoload/coquille.vim#L103
