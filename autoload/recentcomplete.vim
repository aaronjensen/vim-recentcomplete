let s:max_buffer_size = 200000
let s:max_untracked_files = 10

function! s:git_diff(args)
  return " git diff --diff-filter=AM --no-color ".a:args." 2>/dev/null | grep \\^+ 2>/dev/null | grep -v '+++ [ab]/' 2>/dev/null || true"
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

  let l:command = "echo '".s:shellescape(l:buffer)."' | ".s:git_diff('--no-index -- '.l:base.' -')
  return { 'command': l:command }
endfunction

function! s:untracked_keywords()
  let l:command = 'git ls-files --others --exclude-standard 2>/dev/null | head -'
        \. s:max_untracked_files
        \. ' | xargs -I % '.s:git_diff('--no-index /dev/null %')
  return { 'command': l:command }
endfunction

function! s:uncommitted_keywords()
  let l:command = s:git_diff('HEAD')
  return { 'command': l:command }
endfunction

let s:commit_cache = {}

function! s:recently_committed_keywords()
  let l:head = s:system("git rev-parse HEAD 2>/dev/null || echo nogit")
  if has_key(s:commit_cache, l:head)
    return { 'result': s:commit_cache[l:head] }
  endif

  " TODO: cache, maybe one commit at a time
  " To get commits:
  " git log --after="30 minutes ago" --format=%H
  " Then for each:
  " git show --pretty=format: --no-color <SHA>
  let l:command = s:git_diff("@'{1.hour.ago}' HEAD")
  return { 'command': l:command, 'extract': '<SID>process_recently_committed_keywords' }
endfunction

function! s:process_recently_committed_keywords(diff) abort
  let l:diff = join(reverse(split(a:diff, '\n')), "\n")
  let l:result = s:extract_keywords_from_diff(l:diff)

  let l:head = s:system("git rev-parse HEAD 2>/dev/null || echo nogit")
  let s:commit_cache[l:head] = l:result
  return l:result
endfunction

function! s:run_command(command) abort
  if has_key(a:command, 'result')
    return a:command.result
  endif

  let l:diff = s:system(a:command.command)
  if has_key(a:command, 'extract')
    return eval(a:command.extract . '(l:diff)')
  endif

  return s:extract_keywords_from_diff(l:diff)
endfunction

function! s:run_commands(commands) abort
  let l:keywords = []
  for l:command in a:commands
    let l:keywords += s:run_command(l:command)
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

  let l:keywords = s:run_commands(l:commands)

  let l:base = escape(a:keyword_base, '\\/.*$^~[]')
  let l:result = filter(l:keywords, "v:val =~# '^".l:base."'")
  call map(l:result, "{ 'word': v:val, 'menu': '~' }")
  return l:result
endfunction

function! s:system(command) abort
  RCPython import recentcomplete
  RCPython recentcomplete.run_command()
endfunction

" function! s:run_command(command)
"   return system(command)
" endfunction

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
