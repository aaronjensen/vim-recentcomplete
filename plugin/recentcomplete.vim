augroup recentcomplete
  autocmd!
  autocmd CursorMovedI * call recentcomplete#update_cache_eventually()
  autocmd BufWritePost,FileWritePost * call recentcomplete#update_cache()
augroup END

call recentcomplete#update_cache()
