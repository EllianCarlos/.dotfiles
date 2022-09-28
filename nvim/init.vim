set number
set mouse=a
set numberwidth=1
set clipboard=unnamed
syntax enable
set showcmd
set ruler
set encoding=utf-8
set showmatch
set sw=2
set relativenumber
set laststatus
set noshowmode

noremap ç l
noremap l k
noremap k j
noremap j h

call plug#begin('~/.config/nvim/plugged')

Plug 'dense-analysis/ale'
Plug 'scrooloose/nerdtree'
Plug 'jiangmiao/auto-pairs'
Plug 'Shougo/deoplete.nvim'
"" Doesn't work:
"" Plug 'ternjs/tern_for_vim'
Plug 'carlitux/deoplete-ternjs'
Plug 'dracula/vim'
Plug 'ryanoasis/vim-devicons'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'junegunn/goyo.vim'

call plug#end()

nmap <Leader>s <Plug>(easymotion-s2)
nmap <Leader>nt :NERDTreeFind<CR>
nmap <CR> o<Esc>
nmap <Leader>w :w<CR>
nmap <Leader>q :q<CR>
imap jj <Esc>
imap <A-j> <Down>
imap <A-k> <Up>
imap <A-l> <Right>
imap <A-h> <Left>

"" ALE 
"" Allow prettier to format files
""let g:ale_fixers = {
""\   	'javascript': ['prettier', 'eslint'],
""\	'typescript': ['prettier', 'eslint'],
""\   	'css': ['prettier'],
""\}
"" Set ALE to fix on save
"" let g:ale_fix_on_save = 1

"" COC

"" COC Prettier Commands
command! -nargs=0 Prettier :call CocAction('runCommand', 'prettier.formatFile')

"" COC Eslint Commands
command! -nargs=0 ESLint :call CocAction('runCommand', 'eslint.lintProject')
command! -nargs=0 ESLintFix :call CocAction('runCommand', 'eslint.executeAutofix')

"" Macros - Testing
let @i = ":Prettier\<Enter>"
let @o = ':ESLintFix\<Enter>'

