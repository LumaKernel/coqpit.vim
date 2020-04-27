---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

(
  Option:
  You can use below in vimrc to dumping logs to `coqpit-debug.log`

  ```
  let g:coqpit#debug = 1
  augroup coqpit-debug
    autocmd VimLeave * silent! call writefile(coqpit#logger#get_log(), expand('~/coqpit-debug.log'))
  augroup END
  ```
  
  It's not always needed. If ok, the log file may help you and us to debug.
  Caution: Log file will be very huge and include your editing coq file.
  
  <details>
    <summary>dump log</summary>
    ...
  </details>
)


**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Desktop (please complete the following information):**
 - OS: [Windows 7/10 / macOS / Linux (Including distribution) ]
 - Vim or Neovim version ( `vim --version` / `nvim --version` ):
```
paste your vim version info
```
 - Coq version ( `coqc --version` ):
 - Coq version in vim ( `:echo coqpit#coq_version()` from vim ):
 - coqpit.vim version ( `:echo coqpit#version()` from vim ):
