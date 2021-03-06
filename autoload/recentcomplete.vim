let s:max_buffer_size = 200000
let s:max_untracked_files = 10

" TODO: Get rid of this and move buffer_keywords to python
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

function! s:matches(keyword_base) abort
  let commands = [
        \   s:buffer_keywords(),
        \ ]

  let output = join(s:py_run_commands(commands))
  let output .= s:py_get_cache()
  let keywords = s:extract_keywords_from_diff(output)

  let base = escape(a:keyword_base, '\\/.*$^~[]')
  let result = filter(keywords, "v:val =~# '^".base."'")
  call map(result, "{ 'word': v:val, 'menu': '~' }")
  return result
endfunction

function! s:py_get_cache() abort
  RCPython recentcomplete.get_cache()
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

" XXX: Too many different cache update functions is pretty gross.

" debounces the cache update so we can use it on things like CursorMovedI.
" will update the cache 2 seconds after the last time this was called.
function! recentcomplete#update_cache_eventually() abort
  RCPython recentcomplete.update_cache_eventually()
endfunction

" Updates the cache asap, though in a background thread.
function! recentcomplete#update_cache() abort
  RCPython recentcomplete.update_cache()
endfunction

" Updates the cache immediately and synchronously
function! recentcomplete#update_cache_now() abort
  RCPython recentcomplete.update_cache_now()
endfunction

function! recentcomplete#on_quit() abort
  RCPython recentcomplete.clear_timers()
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
