augroup recentcomplete
  autocmd!
  autocmd CursorMoved,CursorMovedI * call recentcomplete#update_cache_eventually()
  autocmd CursorHold,CursorHoldI * call recentcomplete#update_cache()
  autocmd BufWritePost,FileWritePost * call recentcomplete#update_cache()
  autocmd FocusGained * call recentcomplete#update_cache()
  autocmd VimLeavePre * call recentcomplete#on_quit()
augroup END

call recentcomplete#update_cache()
