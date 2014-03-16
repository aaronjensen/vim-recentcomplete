let s:max_buffer_size = 200000
let s:max_untracked_files = 10

function! s:git_diff(args, ...)
  let extra = ''
  if a:0 > 0
    let extra = a:1
  endif
  return " git diff --diff-filter=AM --no-color " . a:args ." 2>/dev/null"
        \. " | grep \\^+\s*.. 2>/dev/null"
        \. " | grep -v '+++ [ab]/' 2>/dev/null"
        \. extra
        \. " || true"
endfunction

function! s:buffer_contents()
  " if &fileformat ==# "dos"
  "   let eol = "\r\n"
  " elseif &fileformat ==# "mac"
  "   let eol = "\r"
  " else
  "   let eol = "\n"
  " endif
  let eol = "\n"
  return join(getbufline(bufname('%'), 1, '$'), eol) . eol
endfunction

function! s:find_start()
  let l:line = getline('.')
  let l:start = col('.') - 1

  while l:start > 0 && l:line[l:start - 1] =~ '\k'
    let l:start -= 1
  endwhile

  return l:start
endfunction

function! s:extract_keywords_from_diff(diff)
  let l:lines = filter(split(a:diff, "\n"), 'v:val =~# ''^+\(++ [ab]\)\@!''')
  let l:lines = map(l:lines, 'strpart(v:val, 1)')

  return split(substitute(join(l:lines), '\k\@!.', ' ', 'g'))
endfunction

function! s:shellescape(str)
  return substitute(a:str, "'", "'\"'\"'", 'g')
endfunction

function! s:buffer_keywords()
  let l:base = '/dev/null'
  if filereadable(expand('%'))
    let l:base = expand('%')
  endif

  let l:buffer = strpart(s:buffer_contents(), 0, s:max_buffer_size)

  return "echo '".s:shellescape(l:buffer)."' | ".s:git_diff('--no-index -- '.l:base.' -')
endfunction

function! s:untracked_keywords()
  return 'git ls-files --others --exclude-standard 2>/dev/null | head -'
        \. s:max_untracked_files
        \. ' | xargs -I % '.s:git_diff('--no-index /dev/null %')
endfunction

function! s:uncommitted_keywords()
  return s:git_diff('HEAD')
endfunction

function! s:recently_committed_keywords()
  return s:git_diff("@'{1.hour.ago}' HEAD", "| sed '1!G;h;$!d' 2>/dev/null")
endfunction

function! s:run_commands_in_parallel(commands) abort
  let l:outputs = s:py_run_commands(a:commands)

  let l:keywords = []
  for l:output in l:outputs
    let l:keywords += s:extract_keywords_from_diff(l:output)
  endfor
  return l:keywords
endfunction

function! s:matches(keyword_base) abort
  let l:commands = [
        \   s:buffer_keywords(),
        \   s:untracked_keywords(),
        \   s:uncommitted_keywords(),
        \   s:recently_committed_keywords(),
        \ ]

  let l:keywords = s:run_commands_in_parallel(l:commands)

  let l:base = escape(a:keyword_base, '\\/.*$^~[]')
  let l:result = filter(l:keywords, "v:val =~# '^".l:base."'")
  call map(l:result, "{ 'word': v:val, 'menu': '~' }")
  return l:result
endfunction

function! s:py_run_command(command) abort
  RCPython import recentcomplete
  RCPython recentcomplete.run_command()
endfunction

function! s:py_run_commands(commands) abort
  RCPython import recentcomplete
  RCPython recentcomplete.run_commands()
endfunction

function! recentcomplete#matches(find_start, keyword_base) abort
  if a:find_start
    return s:find_start()
  else
    return s:matches(a:keyword_base)
  endif
endfunction

if has('python')
  command! -nargs=1 RCPython python <args>
elseif has('python3')
  command! -nargs=1 RCPython python3 <args>
else
  echoerr "No Python support found"
end

RCPython << PYTHON
import sys, os, vim
sys.path.insert(0, os.path.join(vim.eval("expand('<sfile>:p:h:h')"), 'pylibs'))
PYTHON

call s:py_run_commands(['ls', 'echo hi'])
