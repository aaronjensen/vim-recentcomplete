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
        \. " | sed 's/^+//' 2>/dev/null"
        \. extra
        \. " || true"
endfunction

function! s:buffer_contents()
  let eol = "\n"
  return join(getbufline(bufname('%'), 1, '$'), eol) . eol
endfunction

function! s:find_start()
  let line = getline('.')
  let start = col('.') - 1

  while start > 0 && line[start - 1] =~ '\k'
    let start -= 1
  endwhile

  return start
endfunction

function! s:extract_keywords_from_diff(diff)
  return split(substitute(a:diff, '\k\@!.', ' ', 'g'))
endfunction

function! s:shellescape(str)
  return substitute(a:str, "'", "'\"'\"'", 'g')
endfunction

function! s:buffer_keywords()
  let base = '/dev/null'
  if filereadable(expand('%'))
    let base = expand('%')
  endif

  let buffer = strpart(s:buffer_contents(), 0, s:max_buffer_size)

  return "echo '".s:shellescape(buffer)."' | ".s:git_diff('--no-index -- '.base.' -')
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
  let outputs = s:py_run_commands(a:commands)

  let keywords = []
  for output in outputs
    let keywords += s:extract_keywords_from_diff(output)
  endfor
  return keywords
endfunction

function! s:matches(keyword_base) abort
  let commands = [
        \   s:buffer_keywords(),
        \   s:untracked_keywords(),
        \   s:uncommitted_keywords(),
        \   s:recently_committed_keywords(),
        \ ]

  let keywords = s:run_commands_in_parallel(commands)

  let base = escape(a:keyword_base, '\\/.*$^~[]')
  let result = filter(keywords, "v:val =~# '^".base."'")
  call map(result, "{ 'word': v:val, 'menu': '~' }")
  return result
endfunction

function! s:py_run_command(command) abort
  RCPython recentcomplete.run_command()
endfunction

function! s:py_run_commands(commands) abort
  RCPython recentcomplete.run_commands()
endfunction

function! recentcomplete#matches(find_start, keyword_base) abort
  if a:find_start
    return s:find_start()
  else
    return s:matches(a:keyword_base)
  endif
endfunction

" debounces the cache update so we can use it on things like CursorMovedI.
" will update the cache 2 seconds after the last time this was called.
function! recentcomplete#update_cache_eventually() abort
  RCPython recentcomplete.update_cache_eventually()
endfunction

" Updates the cache immediately, though in a background thread.
function! recentcomplete#update_cache() abort
  RCPython recentcomplete.update_cache()
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
import recentcomplete
PYTHON

call s:py_run_commands(['ls', 'echo hi'])
