scriptencoding utf8

function codesearchindex#declareindex(idx_dir, src_dir, manifest_cmd, bin_dir)
    if !isdirectory(a:src_dir)
        echoerr "Source directory does not exist" . a:src_dir
        return 0
    endif

    if !isdirectory(a:idx_dir)
        echoerr "Index directory does not exist" . a:idx_dir
        return 0
    endif

    if !isdirectory(a:bin_dir)
        echoerr "Binaries directory does not exist" . a:bin_dir
        return 0
    endif

    if !executable(a:bin_dir . '/cindex')
        echoerr "cindex not found in binaries directory" . a:bin_dir
        return 0
    endif

    if !executable(a:bin_dir . '/csearch')
        echoerr "csearch not found in binaries directory" . a:bin_dir
        return 0
    endif

    let s:cindex_parameters = { 'idx_base_dir'                 : a:idx_dir
                            \ , 'idx_tmp_dir'                  : a:idx_dir . '/tmp'
                            \ , 'idx_out_dir'                  : a:idx_dir . '/idx'
                            \ , 'idx_file'                     : a:idx_dir . '/idx/_index_'
                            \ , 'src_dir'                      : a:src_dir
                            \ , 'idx_bin'                      : a:bin_dir . '/cindex'
                            \ , 'src_bin'                      : a:bin_dir . '/csearch'
                            \ , 'manifest_cmd'                 : a:manifest_cmd
                            \ , 'manifest_output'              : a:idx_dir . '/tmp/filelist.txt'
                            \ , 'filtered_manifest_output'     : a:idx_dir . '/tmp/filtered_filelist.txt'
                            \ , 'manifest_err_output'          : a:idx_dir . '/tmp/filelist_err.txt'
                            \ , 'search_output'                : a:idx_dir . '/tmp/search.txt'
                            \ , 'search_err_output'            : a:idx_dir . '/tmp/search_err.txt'
                            \ }

    let g:cindex_timer = timer_start(2*60*1000, 'codesearchindex#timerupdateindex', { "repeat":-1 })
endfunction

function codesearchindex#cleanup()
    for f in glob($TEMP . '/csearch*', 0 , 1)
        if localtime() - getftime(f) > 300
            call delete(f)
        endif
    endfor
endfunction

function codesearchindex#isIndexationRunning()
    return (exists('s:cur_idx_job') && job_status(s:cur_idx_job) == 'run') ? 1 : 0
endfunction

function codesearchindex#killIndexation()
    if codesearchindex#isIndexationRunning()
        call job_stop(s:cur_idx_job, 'kill')
        unlet s:cur_idx_job
    endif
    call codesearchindex#cleanup()
endfunction

function codesearchindex#makefilelistandindex()

    if !exists('s:cindex_parameters')
        echoerr "index not initialized"
        return
    endif

    call codesearchindex#killIndexation()

    if filereadable(s:cindex_parameters["idx_file"])
        echomsg "Recreating index"
        call delete(s:cindex_parameters["idx_file"])
    endif

    silent! call mkdir(s:cindex_parameters["idx_base_dir"])
    silent! call mkdir(s:cindex_parameters["idx_tmp_dir"])
    silent! call mkdir(s:cindex_parameters["idx_out_dir"])

    let s:cur_idx_job = job_start( s:cindex_parameters["manifest_cmd"]
        \                        , { "cwd"      : s:cindex_parameters["src_dir"]
        \                          , "out_io"   : "file"
        \                          , "out_name" : s:cindex_parameters["manifest_output"]
        \                          , "err_io"   : "file"
        \                          , "err_name" : s:cindex_parameters["manifest_err_output"]
        \                          , "exit_cb"  : "codesearchindex#checkmanifest"
        \                          }
        \                        )
    call codesearchindex#cleanup()
endfunction

function codesearchindex#stop()
    if !exists('s:cindex_parameters')
        return
    endif
    call codesearchindex#killIndexation()
    call timer_stop(g:cindex_timer)
endfunction

function codesearchindex#checkmanifest(jobno, exitcode)
    if !exists('s:cindex_parameters')
        echoerr "index not initialized"
        return
    endif

    if codesearchindex#isIndexationRunning()
        echoerr "Cannot make index while another operation is in progress"
        return
    endif

    if !filereadable(s:cindex_parameters["manifest_output"])
        echoerr "No manifest file created"
        return
    endif

    let manifest_lines = readfile(s:cindex_parameters["manifest_output"])
    silent! exec 'lchdir ' . s:cindex_parameters["src_dir"]
    call map(manifest_lines, 'substitute(v:val, ''\r$'', "", "g")')
    call filter(manifest_lines, 'v:val !~ ''^$\|[/\\]$'' && filereadable(v:val)')
    call map(manifest_lines, 's:cindex_parameters["src_dir"] . "/" . v:val')
    call sort(manifest_lines)
    call uniq(manifest_lines)
    if has('win32') && exists('+shellslash')
        call map(manifest_lines, 'substitute(v:val, ''/'', ''\'', ''g'')')
    endif
    silent! lchdir!
    if empty(manifest_lines)
        echoerr "Manifest empty"
        return
    endif
    call writefile(manifest_lines, s:cindex_parameters["filtered_manifest_output"])

    call codesearchindex#makeindex()
endfunction

function codesearchindex#makeindex()

    if !exists('s:cindex_parameters')
        echoerr "index not initialized"
        return
    endif

    if codesearchindex#isIndexationRunning()
        echoerr "Cannot make index while another operation is in progress"
        return
    endif

    if filereadable(s:cindex_parameters["idx_file"])
        echoerr "Already indexed"
        return
    endif

    call system(s:cindex_parameters["idx_bin"] . ' -indexpath "' . s:cindex_parameters["idx_file"] . '" -reset')
    let idx_command = s:cindex_parameters["idx_bin"] . ' -indexpath "' . s:cindex_parameters["idx_file"] . '" -maxlinelen 20000 -maxtrigrams 1000000 -maxinvalidutf8ratio 100 -filelist "' . s:cindex_parameters["filtered_manifest_output"] . '"'
    let s:cur_idx_job = job_start( idx_command
        \                        , { "cwd"      : s:cindex_parameters["idx_out_dir"]
        \                          , "out_io"     : "null"
        \                          , "stoponexit" : ""
        \                          }
        \                        )
    call codesearchindex#cleanup()
endfunction

function codesearchindex#timerupdateindex(timer_id)
    if codesearchindex#isIndexationRunning()
        return
    endif

    call codesearchindex#updateindex()
endfunction

function codesearchindex#updateindex()

    if !exists('s:cindex_parameters')
        echoerr "index not initialized"
        return
    endif

    if !filereadable(s:cindex_parameters["idx_file"])
        echomsg "No index, creating"
        call codesearchindex#makefilelistandindex()
        return
    endif

    if codesearchindex#isIndexationRunning()
        echoerr "Cannot update index while another operation is in progress"
        return
    endif

    let idx_command = s:cindex_parameters["idx_bin"] . ' -indexpath "' . s:cindex_parameters["idx_file"] . '" -maxlinelen 20000 -maxtrigrams 1000000 -maxinvalidutf8ratio 100'
    let s:cur_idx_job = job_start( idx_command
        \                        , { "cwd"      : s:cindex_parameters["idx_out_dir"]
        \                          , "out_io"     : "null"
        \                          , "stoponexit" : ""
        \                          }
        \                        )
    call codesearchindex#cleanup()
endfunction

function codesearchindex#searchindex(bang, isword, pattern)
    sil! unlet s:cur_search_pattern

    let isword_delimiter = a:isword == 1 ? '\b' : ''
    let escaped_pattern = '"' . isword_delimiter . escape(a:pattern, '\"') . isword_delimiter . '"'

    if !exists('s:cindex_parameters')
        echoerr "index not initialized"
        return
    endif

    if !filereadable(s:cindex_parameters["idx_file"])
        echomsg "No index, creating"
        call codesearchindex#makefilelistandindex()
        return
    endif

    " Start search process
    let idx_command = s:cindex_parameters["src_bin"] . ' -indexpath "' . s:cindex_parameters["idx_file"] . '" -n ' . (a:bang ==# '!' ? '-i ' : '') . escaped_pattern
    let s:cur_src_job = job_start( idx_command
        \                        , { "cwd"      : s:cindex_parameters["src_dir"]
        \                          , "out_io"   : "file"
        \                          , "out_name" : s:cindex_parameters["search_output"]
        \                          , "err_io"   : "file"
        \                          , "err_name" : s:cindex_parameters["search_err_output"]
        \                          }
        \                        )

    " If job started correctly, start timer to check results availability
    if job_status(s:cur_src_job) == 'fail'
        echoerr "Fail to start job"
        return
    endif

    let s:cur_search_pattern = a:pattern
    let s:cur_word_search_pattern = a:isword

    let g:cindex_timer = timer_start(50, 'codesearchindex#checkresults', { "repeat":-1 })
    call codesearchindex#cleanup()
endfunction

function codesearchindex#searchfromregister(bang, regname)
    exec 'let reg_content=@'.a:regname

    if reg_content =~ '^$'
        echoerr "Register " . a:regname . " is empty"
        return
    endif

    let regexed_pattern = substitute(reg_content,'[ \\*+()\[\]{}?.]','[&]','g')
    let escaped_search_pattern = escape(regexed_pattern, '\ ')

    call codesearchindex#searchindex(a:bang, 0, escaped_search_pattern)
endfunction

function codesearchindex#checkresults(timer_id)

    if !exists('s:cur_src_job')
        " Job has been reset...
        call timer_stop(a:timer_id)
    endif

    if job_status(s:cur_src_job) == 'run'
        return
    endif

    " Job completed, do not call again
    call timer_stop(a:timer_id)

    " results obtained
    setlocal efm=%f:%l:%m
    execute 'cfile ' . s:cindex_parameters["search_output"]

    " Take 25% of window height for search results
    execute 'copen ' . (&lines / 4)
    setlocal nowrap
    copen "make it the current window
    if exists('s:cur_search_pattern')
        if s:cur_word_search_pattern == 1
            call clearmatches()
            let word_regex='\%(\i\+::\)*\zs' . '\<' . s:cur_search_pattern . '\>' . '\ze'
            " comments
            call matchadd('Comment', '[/][*]\%(.\{-}[*][/]\|.*\)')
            call matchadd('Comment', '[/][/].*')
            call matchadd('Comment', '|\d\+| \zs|.*')
            if exists('g:cindex_comment_patterns')
                for i in g:cindex_comment_patterns
                    call matchadd('Comment', i)
                endfor
            endif

            " class /X/, struct /X/, public /X/, new /X/, ...
            call matchadd('DiffChange', '\v<%(class|struct|public|private|protected|new)>\m\s\+' . word_regex)
            " /X/ <mot> : constructor
            call matchadd('DiffChange', '\i\+\s\+' . word_regex)
            " <mot> /X/ : declaration
            call matchadd('DiffChange', word_regex . '\s\+\i\+')
            " /X/(... : function call
            call matchadd('DiffChange', word_regex . '\s*(')
            " /X/{... : C++11 constructor
            call matchadd('DiffChange', word_regex . '\s*{')

            " no control flow keyword, and final parenthesis: function body
            call matchadd('DiffAdd', '^\%(.\{-}|\d\+| \s*\)\@>\%(if\|for\|while\|switch\)\@!.*' . word_regex . '.*(.*)\s*{\=\s*$')
        endif
    endif
    cfirst
endfunction
