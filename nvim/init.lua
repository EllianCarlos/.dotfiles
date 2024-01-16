  vim.cmd([[
let mapleader=","

set number
set mouse=a
set numberwidth=1
set clipboard=unnamed
syntax enable
set showcmd
set ruler
set encoding=UTF-8
set showmatch
set sw=2
set relativenumber
set laststatus
set noshowmode

set guifont=Fira\ Code:h12

noremap ç l
noremap l k
noremap k j
noremap j h

call plug#begin('~/.config/nvim/plugged')

Plug 'ryanoasis/vim-devicons'
Plug 'lambdalisue/fern.vim'

Plug 'jiangmiao/auto-pairs'
Plug 'dracula/vim'
Plug 'junegunn/goyo.vim'

Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

Plug 'junegunn/fzf', {  'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/mason.nvim'

Plug 'mfussenegger/nvim-lint'
Plug 'rshkarin/mason-nvim-lint'

Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.0' }

call plug#end()

" air-line
let g:airline_powerline_fonts = 1

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif

" unicode symbols
let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'
let g:airline_symbols.linenr = '␊'
let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline_symbols.whitespace = 'Ξ'
" airline symbols                                                                                                                              
let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''

let g:WebDevIconsUnicodeDecorateFolderNodes = 1
let g:WebDevIconsUnicodeDecorateFolderNodeDefaultSymbol = ''

let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols = {}


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

"" TODO
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

require ('mason-nvim-lint').setup({
    ensure_installed = {'eslint_d', 'prettierd'},
})

local builtin = require('telescope.builtin')
vim.keymap.set('n', 'ff', builtin.find_files, {})
vim.keymap.set('n', 'fg', builtin.live_grep, {})
vim.keymap.set('n', 'fb', builtin.buffers, {})
vim.keymap.set('n', 'fh', builtin.help_tags, {})
