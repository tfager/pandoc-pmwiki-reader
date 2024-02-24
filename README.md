# pandoc-pmwiki-reader
Lua script to read PMWiki markup into pandoc


Try it out with:
```
pandoc -f pmwiki_reader.lua -t gfm --wrap=preserve testfile.pmwiki
```
* `--wrap=preserve` to avoid word wrap inside links
* `gfm` instead of `markdown` to get tables with pipes

## Issues

* Can't handle strong/emphasized text with links inside
* Several constructs unsupported: https://www.pmwiki.org/wiki/PmWiki/MarkupMasterIndex

