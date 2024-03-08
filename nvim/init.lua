  vim.cmd([[
let mapleader=","

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

Plug 'scrooloose/nerdtree'
Plug 'jiangmiao/auto-pairs'
Plug 'dracula/vim'
Plug 'ryanoasis/vim-devicons'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'junegunn/goyo.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'junegunn/fzf', {  'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/mason.nvim'

Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.0' }

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

"" COC

"" COC Prettier Commands
command! -nargs=0 Prettier :call CocAction('runCommand', 'prettier.formatFile')

"" COC Eslint Commands
command! -nargs=0 ESLint :call CocAction('runCommand', 'eslint.lintProject')
command! -nargs=0 ESLintFix :call CocAction('runCommand', 'eslint.executeAutofix')

"" Macros - Testing
let @i = ":Prettier\<Enter>"
let @o = ':ESLintFix\<Enter>'

nmap <Leader>i :Prettier<CR>
nmap <Leader>o :ESLintFix<CR>


"" Move Between Windows
nmap <silent> <c-k> :wincmd k<CR>
nmap <silent> <c-j> :wincmd j<CR>
nmap <silent> <c-h> :wincmd h<CR>
nmap <silent> <c-l> :wincmd l<CR>

]])

require("mason").setup()

local builtin = require('telescope.builtin')
vim.keymap.set('n', 'ff', builtin.find_files, {})
vim.keymap.set('n', 'fg', builtin.live_grep, {})
vim.keymap.set('n', 'fb', builtin.buffers, {})
vim.keymap.set('n', 'fh', builtin.help_tags, {})
