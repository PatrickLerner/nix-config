-- options.lua - General Neovim settings

local opt = vim.opt

-- [[ Setting options ]]
-- See `:help vim.opt`

-- Encoding
opt.encoding = 'utf-8'

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
opt.mouse = ''

-- Don't show the mode, since it's already in the status line
opt.showmode = false

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
opt.clipboard = 'unnamedplus'

-- Enable break indent
opt.breakindent = true

-- Save undo history
opt.undofile = true
opt.undodir = vim.fn.expand('~/.vim/undodir')

-- Case-insensitive searching UNLESS \C or capital in search
opt.ignorecase = true
opt.smartcase = true

-- Keep signcolumn on by default
opt.signcolumn = 'yes'

-- Decrease update time
opt.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
opt.timeoutlen = 300

-- Configure how new splits should be opened
opt.splitright = true
opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
opt.list = true
opt.listchars = { tab = '→ ', trail = '•', nbsp = '␣', extends = '⟩', precedes = '⟨' }
opt.showbreak = '↪ '

-- Preview substitutions live, as you type!
opt.inccommand = 'split'

-- Show which line your cursor is on
opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
opt.scrolloff = 10

-- From original config
opt.backspace = 'indent,eol,start'
opt.history = 1000
opt.ruler = true
opt.showcmd = true
opt.complete:remove('i')
opt.showmatch = true
opt.wrap = true
opt.linebreak = true
opt.backupdir = vim.fn.expand('~/.tmp')
opt.directory = vim.fn.expand('~/.tmp')
opt.autoread = true
opt.expandtab = true
opt.smarttab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.incsearch = false
opt.gdefault = true
opt.autoindent = true
opt.lazyredraw = true
opt.endofline = true
opt.hlsearch = true
opt.incsearch = true
opt.laststatus = 2

-- Folding
opt.foldmethod = 'indent'
opt.foldnestmax = 10
opt.foldenable = false
opt.foldlevel = 2

-- Persistent undo
opt.undodir = vim.fn.expand('~/.vim/undodir')
opt.undofile = true

-- Disable mouse
opt.mouse = ''

-- Show special characters for whitespace
opt.showbreak = '↪\\'
opt.listchars = {
  tab = '→ ',
  nbsp = '␣',
  trail = '•',
  extends = '⟩',
  precedes = '⟨'
}
opt.list = true

-- Wild ignore patterns
opt.wildignore:append('.DS_Store')
opt.wildignore:append('.git/')
opt.wildignore:append('node_modules/')

-- True color support
if vim.fn.has('termguicolors') == 1 then
  opt.termguicolors = true
end