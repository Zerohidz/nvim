nnoremap <buffer> q <cmd>q!<cr>

call cursor(line('$'), 0)
silent! call search('\S', 'b')
silent! call search('\n*\%$')
execute "normal! \<c-y>"

set nonumber
set norelativenumber
set signcolumn=no

" bunlar relativenumber ayarını modifiiye ediyor o yüzden kapatıyorum
autocmd! InsertEnter,InsertLeave
