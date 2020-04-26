---
name: バグ報告 (日本語テンプレート)
about: 調査しやすいようにバグの再現手順などを報告します
title: "[バグ報告] .."
labels: bug
assignees: LumaKernel

---

**バグの説明**
発生しているバグに関する情報を正確に書いてください。

(
  以下のような vim script を使って、 `coqpit-debug.log` ファイルを作ることもできます。
  これはオプションなので、なくてもかまいません。

  ```
  let g:coqpit#debug = 1
  augroup coqpit-debug
    autocmd VimLeave * silent! call writefile(coqpit#logger#get_log(), expand('~/coqpit-debug.log'))
  augroup END
  ```
  
  なお、これによって生成されるログファイルには、ログを作成するにあたって編集した coq ファイルなどが含まれたりするので、
  Issue用の作業用ファイルなどを作るなどしておいてください。
  
  <details>
    <summary>ログ</summary>
    ログの内容を貼り付けてください (もしかしたら長すぎて貼れないかもしれません。その場合は後ろだけ貼ったりしてください。)。
    もし何か問題がある場合は、メールで送るなどの手段を気軽に相談してください。Issue を出した後にコメントで相談していただければ大丈夫です。
  </details>
)


**バグの再現手順**
ほかの人の環境でも再現できるように、なるべく細かく再現手順を書いてください。
再現できない場合、対応することが非常に難しくなるかもしれません。
( しかし Issue を出すことを恐れないでください。私たちはその問題を一瞬で解決しうるかもしれません。 )
1. '...'
2. '....'
3. '....'
4. 以下のエラーメッセージが出ます
```
<エラーメッセージ>
```

**本来期待する動作**
もしバグがなかった場合に期待される動作を書いてください。

**スクリーンショット**
該当する場合は，スクリーンショットを貼ってください。
ハイライトに関する問題などであればなるべく貼るようにしてください。

**バージョン情報**
以下の情報を埋めてください。追加で必要だと判断した情報も書いてください。

 - OS: [Windows 7/10 / macOS / Linux (Including distribution) ]
 - Vim or Neovim version ( `vim --version` / `nvim --version` ):
```
出力された vim か neovim のバージョンをここに貼り付けてください。
```
 - Coq version ( `coqc --version` ):
 - coqpit.vim version ( `:echo coqpit#version()` from vim ):
