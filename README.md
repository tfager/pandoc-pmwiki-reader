# pandoc-pmwiki-reader
Lua script to read PMWiki markup into pandoc


Try it out with:
```
pandoc -f pmwiki_reader.lua -t gfm --wrap=preserve testfile.pmwiki
```
* `--wrap=preserve` to avoid word wrap inside links
* `gfm` instead of `markdown` to get tables with pipes

Note that PMWiki stores other metadata in its data files besides the PMWiki markup,
so you will need to preprocess them, for example like so:
```
cat wiki.d/Example.Page | grep -a "^text=" | sed "s/^text=//" | sed "s/%0a/\n/g" | sed "s/%25/%/g" | sed "s/%3c/</g" | pandoc -f pmwiki_reader.lua -o Example.Page.pdf
```


## Issues

* Can't handle strong/emphasized text with links inside
* Several constructs unsupported: https://www.pmwiki.org/wiki/PmWiki/MarkupMasterIndex

