# Coquille


## WIP

a


## TODO

- [x] bug: coq-next at end
- [x] bug: Notation "'""'" ...
- [x] Swap warning and admit colors in cterm

- [x] option `update_status_always`
  - This fixes [Coq issues #9680](https://github.com/coq/coq/issues/9680)

- [ ] When job terminated, restart job
- [ ] Stop job command
- [x] Move to Top
- [x] Coq to Last
- [ ] Query command

- [ ] Goals syntax
  - [ ] For now, minimum.
- [ ] Infos syntax
  - [ ] For now, minimum.
- [ ] Multiple buffer support
  - [ ] one buffer attaches one goal-window and one info-window
  - [ ] bug: switching buffers with highligh
- [ ] Re-Launch command
- [ ] More flexible settings
  - [ ] Reset window
  - [x] CoqToCursor with ceiling (now, flooring)
  - [ ] `auto launch`
  - [ ] `auto open window`
  - [ ] `rearrange after focus`
  - [ ] `rerun after focus`
- [ ] document about custimize window

- [ ] Screenshots

- [x] version chekcking
- [ ] version echo

- windows gui checking
  - [x] Coq 3.5pl3 works
  - [ ] Coq 3.6 works
  - [x] Coq 3.7 works
  - [ ] Coq 3.8 works
  - [x] Coq 3.9 works
  - [x] Coq 3.10 works
  - [x] Coq 3.11beta works
  - [x] `coqtopide.opt.exe`  works

- windows cui checking ( `win32unix` )
  - [x] Coq 3.7 works
  - [x] Coq 3.9 works

- [ ] other OS

- [x] specifying Coq binary
  - [x] `g:coquille_coq_executable`
- [x] Clearify dependencies
  - [x] ~~python version~~
  - [x] Coq version
- [x] Fix bugs
  - found bugs in original version were almostly fixed.
- [x] Highlighting Erros in Editor
- [x] Python2 to Python3 ... ? ( Is it needed ? )
  - re-write in vim script !!
- [x] write tests

- [x] ~~Jump to Error line~~
  - Maybe not needed.

Not easy ones.

- [ ] Vim friendly Search Interface
- [ ] Compile Coq in Vim
  - [ ] `rerun after compile`
- [ ] Queue all command
- [ ] Jump to Axiom
  - Sounds good for rewriting `admit.`
- [ ] Setting by Global Variables
  - Hm, it's nasty... make just a function to configure.

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

## Screenshoots

Because pictures are always the best sellers :

![Coquille at use](http://the-lambda-church.github.io/coquille/coquille.png)

## Known Issues

- Without `g:coquille_update_status_always = 0` [coq issues #9680](https://github.com/coq/coq/issues/9680) happens also in this plugin.
  - I recommend you not changing this options.

[1]: https://github.com/tpope/vim-pathogen
[2]: https://github.com/def-lkb/vimbufsync
[3]: http://www.vim.org/scripts/script.php?script_id=2063 "coq syntax on vim.org"
[4]: http://www.vim.org/scripts/script.php?script_id=2079 "coq indent on vim.org"
[5]: https://github.com/the-lambda-church/coquille/blob/master/autoload/coquille.vim#L103
