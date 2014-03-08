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
  return substitute(a:str, "'", '"''"', 'g')
endfunction

function! s:buffer_keywords()
  let l:base = '/dev/null'
  if filereadable(expand('%'))
    let l:base = expand('%')
  endif

  let l:diff = s:run_command("echo '".s:shellescape(s:buffer_contents())."' | ".s:git_diff('--no-index -- '.l:base.' -'))
  return s:extract_keywords_from_diff(l:diff)
endfunction

function! s:untracked_keywords()
  "echom 'git ls-files --others --exclude-standard 2>/dev/null | xargs -I % '.s:git_diff('git diff /dev/null %')
  " echom 'git ls-files --others --exclude-standard | xargs -I % '.s:git_diff('--no-index /dev/null %')
  let l:diff = s:run_command('git ls-files --others --exclude-standard | xargs -I % '.s:git_diff('--no-index /dev/null %'))
  "echom l:diff
  return s:extract_keywords_from_diff(l:diff)
endfunction

function! s:uncommitted_keywords()
  let l:diff = s:run_command(s:git_diff('HEAD'))
  return s:extract_keywords_from_diff(l:diff)
endfunction

let s:commit_cache = {}

function! s:recently_committed_keywords()
  let l:head = s:run_command("git rev-parse HEAD")
  if has_key(s:commit_cache, l:head)
    return s:commit_cache[l:head]
  endif

  " TODO: cache, maybe one commit at a time
  " To get commits:
  " git log --after="30 minutes ago" --format=%H
  " Then for each:
  " git show --pretty=format: --no-color <SHA>
  let l:diff = s:run_command(s:git_diff("@'{8.hours.ago}'"))
  let l:diff = join(reverse(split(l:diff, '\n')), "\n")
  let l:result = s:extract_keywords_from_diff(l:diff)
  let s:commit_cache[l:head] = l:result
  return l:result
endfunction

function! s:matches(keyword_base)
  let l:keywords = s:buffer_keywords()
  let l:keywords += s:untracked_keywords()
  let l:keywords += s:uncommitted_keywords()
  let l:keywords += s:recently_committed_keywords()

  let l:base = escape(a:keyword_base, '\\/.*$^~[]')
  let l:result = filter(l:keywords, "v:val =~# '^".l:base."'")
  call map(l:result, "{ 'word': v:val, 'menu': '~' }")
  return l:result
endfunction

function! s:run_command(command)
  RCPython import recentcomplete
  RCPython recentcomplete.run_command()
endfunction

" function! s:run_command(command)
"   return system(command)
" endfunction

function! recentcomplete#matches(find_start, keyword_base)
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
