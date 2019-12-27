
## Local

Plase check you installed `vital.vim`.

```bash
$ vim -u ./test/test.vimrc
```

### Run always after starting vim

Add following to your `.vimrc`.

```vim
let g:__vital_power_assert_config = {
\   '__debug__': 1
\ }

call coquille#test#runTest()
  \   .then({-> execute('echo "All tests passed."')})
  \   .catch({err -> execute('echoerr err')})
```

