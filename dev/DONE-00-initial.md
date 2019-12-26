
- [x] What this script can read is what the compiler can.
  - Maybe done. Thinking so is better.


- [x] bug: coq-next at end
- [x] bug: Notation "'""'" ...
- [x] Swap warning and admit colors in cterm

- [x] option `update_status_always`
  - This fixes [Coq issues #9680](https://github.com/coq/coq/issues/9680)

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

- [x] When job terminated, restart job
- [x] Move to Top
- [x] Coq to Last
- [x] Coq Re-run command
  - [x] works well
- [x] Coq Re-launch command
  - `:CoqLaunch` is re-launch when running
  - [x] works well
- [x] Coq Refresh command
  - refresh Goals and Infos
  - [x] works well

- windows cui checking ( `win32unix` )
  - [x] Coq 3.7 works
  - [x] Coq 3.9 works
  - [x] Coq 3.10 works


- [x] bug: coq-next very fast

- [x] fire edit-at for wrong tip
- [x] bug: coq-to-cursor and many fast coq-next

- [x] weaken highlight priority less than 0
  - for search hightlight

- [x] ~bug: cursor moves on Goals/Infos window~
  - Not bug. Updating buffer leads cursor moves to top.

- [x] Multiple buffer support
  - [x] one buffer attaches one goal-window and one info-window
    - [x] optional : use one window to all buffers in one tab
  - [x] bug: switching buffers with highlight
- [x] More flexible settings
  - [x] CoqToCursor with ceiling (now, flooring)
  - [x] `auto launch`
  - [x] ~~`auto open window`~~
    - what ? I forgot.
    - maybe resolve by `no open window` option
  - [x] ~`rearrange after focus`~
    - good?
  - [x] `refresh after focus`
    - [x] works well
  - [x] `rerun after focus`
    - [x] works well
- [x] Coq Stop command
  - [x] works well
- [x] Coq StopAll command
  - [x] works well

- [x] version chekcking
- [x] version echo
  - and option `silent`

- [x] ~~no open window option~~
  - not needed because it is impossible to open buffer without
    opening window
- [x] options that not changing Infos/Goals after TextChanged
- [x] name Goals/Infos uniquely
- [x] show errors when booting CoqTop
- [x] use vital
  - XML

- [x] windows gui checking
  - [x] Coq 8.5pl3 works
  - [x] Coq 8.6 works
  - [x] Coq 8.7 works
  - [x] Coq 8.9 works
  - [x] Coq 8.10 works
  - [x] Coq 8.11beta works
  - [x] `coqtopide.opt.exe`  works

- [x] not to use json

- [x] check one-window

- [x] check multiple tabs

- [x] Query command for now

