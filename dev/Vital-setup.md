
## For just coqtop.vim uesr

These installations are not needed.
Just included in coqtop.vim by the `autoload/vital/coqtop.vim`.


## For coqtop.vim developer

There is no way to setup by setting file like a `package.json` for npm.
In this file shows how to reset and reinstall the vital plugins.

### dependencies

- Web.XML (default)
- [Vim.PowerAssert](https://github.com/haya14busa/vital-power-assert)

### dev-dependencies

- Async.Promise (default)
- Random (default)


```
:Vitalize . --name=coqtop.vim Vim.PowerAssert Web.XML Async.Promise Random
```

