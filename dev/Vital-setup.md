
## For just coquille uesr

These installations are not needed.
Just included in coquille by the `autoload/vital/coquille.vim`.


## For coquille developer

There is no way to setup by setting file like a `package.json` for npm.
In this file shows how to reset and reinstall the vital plugins.

### dependencies

- Web.XML (default)
- [Vim.PowerAssert](https://github.com/haya14busa/vital-power-assert)

### dev-dependencies

- Async.Promise (default)


```
:Vitalize . --name=coquille Vim.PowerAssert Web.XML Async.Promise
```


