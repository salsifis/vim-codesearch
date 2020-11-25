This is a vim plugin that helps you interact with [CodeSearch](https://github.com/junkblocker/codesearch).

The goal is to index the contents of all source files within a working directory, and therefore being able
to run instantaneous search queries.

Installation
------------

If you have the Pathogen plugin installed or any other plugin manager, then
just copy this filetree into a subfolder of your Bundle folder.

The use of this plugin requires the binaries of [CodeSearch](https://github.com/junkblocker/codesearch).
Use `go get github.com/junkblocker/codesearch/cmd/...` to build them.

Use
---

Prior to using the plugin you need to know:
* Where your source files are located
* What command can list the files to index
* Where csearch and cindex binaries are stored

Example with the sources of SQLite:
* Checkout sources using fossil:
  * `cd /tmp && mkdir SQLite && cd SQLite`
  * `fossil clone https://sqlite.org/src bare_repository`
  * `mkdir index`
  * `mkdir worktree && cd worktree && fossil open ../bare_repository`
* Declare your index. You need four arguments:
  1. Storage directory for the index
  2. Directory for your worktree
  3. Command listing files when inside the worktree
  4. Directory for the csearch and cindex binaries

  `:call codesearchindex#declareindex('/tmp/index', '/tmp/SQLite/worktree', 'fossil ls', '/opt/codesearch/bin')`

  or:

  `:DeclareIndex /tmp/index /tmp/SQLite/worktree fossil\ ls /opt/codesearch/bin`

  You can make helpers for this command when you intend to work on SQLite.
* Run a first-time indexation: `:MkIndex`
* Perform a search: `:SearchExprInIndex write.*page`
* Fill your clipboard with “as follows:”, then use `:SearchFromRegisterInIndex +` (if your + register is associated with clipboard)

I use (among others) the following mappings:
```
" Use F2 for case-sensitive search, F3 for case-insensitive search
" F2 or F3 on a word: word lookup in index
" F2 or F3 in visual mode: lookup for highlighted text
" Shift-F2 or Shift-F3: lookup for text in clipboard

nnoremap <F2>     :SearchWordInIndex <C-R><C-W><Return>
nnoremap <F3>     :SearchWordInIndex! <C-R><C-W><Return>

xnoremap <F2>     "zy:SearchFromRegisterInIndex z<Return>
xnoremap <F3>     "zy:SearchFromRegisterInIndex! z<Return>

nnoremap <S-F2>   :SearchFromRegisterInIndex +<Return>
nnoremap <S-F3>   :SearchFromRegisterInIndex! +<Return>
```

Development
-----------

The main git repository for this plugin is at
`http://github.com/salsifis/vim-codesearchindex`

License
-------

zlib/libpng license.

Copyright (c) 2020 Benoit Mortgat

This software is provided 'as-is', without any express or implied warranty. In
no event will the authors be held liable for any damages arising from the use
of this software.

Permission is granted to anyone to use this software for any purpose, including
commercial applications, and to alter it and redistribute it freely, subject to
the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim
   that you wrote the original software. If you use this software in a product,
an acknowledgment in the product documentation would be appreciated but is not
required.

2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution.
