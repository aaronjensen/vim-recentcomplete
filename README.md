# vim-recentcomplete [![Build Status](https://travis-ci.org/aaronjensen/vim-recentcomplete.png?branch=master)](https://travis-ci.org/aaronjensen/vim-recentcomplete)

Uses recent git changes to populate autocomplete.

### Use with

* My fork of [vim-autocomplpop](https://github.com/aaronjensen/vim-autocomplpop)
* [vim-localcomplete](https://github.com/dirkwallenstein/vim-localcomplete)

### Example configuration

This is my configuration from my [vimfiles](https://github.com/aaronjensen/vimfiles).
It is primarily set up for ruby and sass but can be customized to anything.

`.vimrc`

```vim
Plugin 'L9'
Plugin 'aaronjensen/vim-autocomplpop'
Plugin 'dirkwallenstein/vim-localcomplete'
Plugin 'aaronjensen/vim-recentcomplete'

" make enter always be enter, even when popup menu is visible.
inoremap <CR> <C-g>u<C-r>=pumvisible()?"\C-y":""<CR><CR>
```

`plugin/mycomplete.vim`

```vim
"let g:rubycomplete_buffer_loading = 1
set complete-=i

let g:acp_colorForward = 'Pmenu'
let g:acp_colorReverse = 'Pmenu'
let g:acp_behaviorKeywordLength = 1
let g:acp_behaviorRubyOmniMethodLength = 0
let g:acp_reverseMappingInReverseMenu = 1
let g:localcomplete#OriginNoteLocalcomplete = '%'
let g:localcomplete#OriginNoteAllBuffers = '+'
let g:localcomplete#OriginNoteDictionary = '*'
let g:localcomplete#LocalMinPrefixLength = 0
let g:localcomplete#AllBuffersMinPrefixLength = 0

" Add $ and - as keyword chars in sass/css/haml as necessary
" $ doesn't work w/ localcomplete
autocmd BufRead,BufNewFile *.{sass,scss} setlocal iskeyword+=$
autocmd BufRead,BufNewFile *.{css,sass,scss,less,styl,haml,html,erb} setlocal iskeyword+=- 
  \| let b:LocalCompleteAdditionalKeywordChars = '-'

" let g:acp_refeed_checkpoints = [2]
if !exists('g:acp_behavior')
  let g:acp_behavior = {}
endif

let g:acp_behavior['*'] = [
  \  {
  \    'command': "\<C-X>\<C-U>",
  \    'completefunc': 'mycomplete#CompleteCombinerText',
  \    'meets': 'acp#meetsForKeyword',
  \    'repeat': 0
  \  },
  \  {
  \    'command' : "\<C-x>\<C-f>",
  \    'meets'   : 'acp#meetsForFile',
  \    'repeat'  : 1,
  \  },
  \  {
  \    'command': "\<C-X>\<C-]>",
  \    'meets': 'mycomplete#MeetsForTags',
  \    'repeat': 0
  \  },
  \]

" Complete keywords first locally, then all buffers
" Complete everything else first locally, then all buffers, then omni
" Include tags if all else fails
let g:acp_behavior['ruby'] = [
  \  {
  \    'command': "\<C-X>\<C-U>",
  \    'completefunc': 'mycomplete#CompleteCombinerRuby',
  \    'meets': 'acp#meetsForRubyOmni',
  \    'repeat': 0
  \  },
  \  {
  \    'command': "\<C-X>\<C-U>",
  \    'completefunc': 'mycomplete#CompleteCombinerText',
  \    'meets': 'acp#meetsForKeyword',
  \    'repeat': 0
  \  },
  \  {
  \    'command' : "\<C-x>\<C-f>",
  \    'meets'   : 'acp#meetsForFile',
  \    'repeat'  : 1,
  \  },
  \  {
  \    'command': "\<C-X>\<C-]>",
  \    'meets': 'mycomplete#MeetsForTags',
  \    'repeat': 0
  \  },
  \]

let g:acp_behavior['css'] = [
  \  {
  \    'command' : "\<C-x>\<C-o>",
  \    'meets'   : 'acp#meetsForCssOmni',
  \    'repeat'  : 1,
  \  },
  \  {
  \    'command' : "\<C-x>\<C-f>",
  \    'meets'   : 'acp#meetsForFile',
  \    'repeat'  : 1,
  \  },
  \  {
  \    'command': "\<C-X>\<C-U>",
  \    'completefunc': 'mycomplete#CompleteCombinerCss',
  \    'meets': 'acp#meetsForKeyword',
  \    'repeat': 1
  \  },
  \  {
  \    'command' : "\<C-p>",
  \    'meets'   : 'acp#meetsForKeyword',
  \    'repeat'  : 0,
  \  },
  \]
let g:acp_behavior['sass'] = g:acp_behavior['css']
let g:acp_behavior['scss'] = g:acp_behavior['css']
```

`autoload/mycomplete.vim`

```vim
function mycomplete#CompleteCombinerText(findstart, keyword_base)
  let l:all_completers = [
        \ 'recentcomplete#matches',
        \ 'localcomplete#localMatches',
        \ 'localcomplete#allBufferMatches',
        \ 'localcomplete#dictMatches',
        \ ]
  return combinerEXP#completeCombinerABSTRACT(
        \ a:findstart,
        \ a:keyword_base,
        \ l:all_completers,
        \ 0)
endfunction

function mycomplete#CompleteCombinerRuby(findstart, keyword_base)
  let l:all_completers = [
        \ 'recentcomplete#matches',
        \ 'localcomplete#localMatches',
        \ 'localcomplete#allBufferMatches',
        \ 'rubycomplete#Complete',
        \ ]
  return combinerEXP#completeCombinerABSTRACT(
        \ a:findstart,
        \ a:keyword_base,
        \ l:all_completers,
        \ 0)
endfunction

function mycomplete#CompleteCombinerCss(findstart, keyword_base)
  let l:all_completers = [
        \ 'recentcomplete#matches',
        \ 'localcomplete#localMatches',
        \ 'localcomplete#allBufferMatches',
        \ ]
  return combinerEXP#completeCombinerABSTRACT(
        \ a:findstart,
        \ a:keyword_base,
        \ l:all_completers,
        \ 0)
endfunction

function mycomplete#MeetsForTags(context)
  if empty(tagfiles())
    return 0
  endif

  return acp#meetsForKeyword(a:context)
endfunction
```
