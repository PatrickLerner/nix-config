-- keymaps.lua - Key mappings

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Disable Q (Ex mode)
vim.keymap.set('n', 'Q', '<nop>')

-- Faster scrolling
vim.keymap.set('n', '<C-e>', '3<C-e>')
vim.keymap.set('n', '<C-y>', '3<C-y>')

-- Disable arrow keys in normal mode
vim.keymap.set('n', '<up>', '<nop>')
vim.keymap.set('n', '<down>', '<nop>')
vim.keymap.set('n', '<left>', '<nop>')
vim.keymap.set('n', '<right>', '<nop>')

-- Easier split navigation
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Replace selection with buffer when pressing r
vim.keymap.set('v', 'r', '"_dP')

-- Keep selection when indenting
vim.keymap.set('v', '<', '<gv')
vim.keymap.set('v', '>', '>gv')

-- Use tab for indentation
vim.keymap.set('n', '<Tab>', '>>_')
vim.keymap.set('n', '<S-Tab>', '<<_')
vim.keymap.set('i', '<S-Tab>', '<C-D>')
vim.keymap.set('v', '<Tab>', '>gv')
vim.keymap.set('v', '<S-Tab>', '<gv')

-- Use escape to leave terminal mode
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>')

-- Remap ; to act like :
vim.keymap.set('n', ';', ':')
vim.keymap.set('n', ':', '<nop>')

-- Leader keymaps
-- Clear highlights
vim.keymap.set('n', '<leader><space>', '<cmd>nohlsearch<CR>', { desc = 'Clear highlights' })

-- System clipboard operations
vim.keymap.set('n', '<leader>y', '"+y', { desc = 'Yank to system clipboard' })
vim.keymap.set('n', '<leader>d', '"+d', { desc = 'Delete to system clipboard' })
vim.keymap.set('v', '<leader>y', '"+y', { desc = 'Yank to system clipboard' })
vim.keymap.set('v', '<leader>d', '"+d', { desc = 'Delete to system clipboard' })
vim.keymap.set('n', '<leader>p', '<cmd>set paste<CR>"+p<cmd>set nopaste<CR>', { desc = 'Paste from system clipboard' })
vim.keymap.set('n', '<leader>P', '<cmd>set paste<CR>"+P<cmd>set nopaste<CR>', { desc = 'Paste before from system clipboard' })
vim.keymap.set('v', '<leader>p', '<cmd>set paste<CR>"+p<cmd>set nopaste<CR>', { desc = 'Paste from system clipboard' })
vim.keymap.set('v', '<leader>P', '<cmd>set paste<CR>"+P<cmd>set nopaste<CR>', { desc = 'Paste before from system clipboard' })

-- Tab navigation
vim.keymap.set('n', '<leader>1', '1gt', { desc = 'Go to tab 1' })
vim.keymap.set('n', '<leader>2', '2gt', { desc = 'Go to tab 2' })
vim.keymap.set('n', '<leader>3', '3gt', { desc = 'Go to tab 3' })
vim.keymap.set('n', '<leader>4', '4gt', { desc = 'Go to tab 4' })
vim.keymap.set('n', '<leader>5', '5gt', { desc = 'Go to tab 5' })
vim.keymap.set('n', '<leader>6', '6gt', { desc = 'Go to tab 6' })
vim.keymap.set('n', '<leader>7', '7gt', { desc = 'Go to tab 7' })
vim.keymap.set('n', '<leader>8', '8gt', { desc = 'Go to tab 8' })
vim.keymap.set('n', '<leader>9', '9gt', { desc = 'Go to tab 9' })
vim.keymap.set('n', '<leader>0', '10gt', { desc = 'Go to tab 10' })
vim.keymap.set('n', '<leader>n', '<cmd>tabnew<CR>', { desc = 'New tab' })

-- Split management
vim.keymap.set('n', '<leader>v', '<cmd>vsp<CR>', { desc = 'Vertical split' })
vim.keymap.set('n', '<leader>b', '<cmd>new<CR>', { desc = 'Horizontal split' })

-- Git (will be configured with fugitive plugin)
vim.keymap.set('n', '<leader>g', '<cmd>Git<CR>', { desc = 'Git status' })

-- Tab navigation with backslash
vim.keymap.set('n', '\\1', '1gt', { desc = 'Go to tab 1' })
vim.keymap.set('n', '\\2', '2gt', { desc = 'Go to tab 2' })
vim.keymap.set('n', '\\3', '3gt', { desc = 'Go to tab 3' })
vim.keymap.set('n', '\\4', '4gt', { desc = 'Go to tab 4' })
vim.keymap.set('n', '\\5', '5gt', { desc = 'Go to tab 5' })
vim.keymap.set('n', '\\6', '6gt', { desc = 'Go to tab 6' })
vim.keymap.set('n', '\\7', '7gt', { desc = 'Go to tab 7' })
vim.keymap.set('n', '\\8', '8gt', { desc = 'Go to tab 8' })
vim.keymap.set('n', '\\9', '9gt', { desc = 'Go to tab 9' })
vim.keymap.set('n', '\\0', '10gt', { desc = 'Go to tab 10' })

-- New tab/buffer with backslash
vim.keymap.set('n', '\\n', '<cmd>tabnew<CR>', { desc = 'New tab' })

-- Telescope live grep search
vim.keymap.set('n', '\\a', '<cmd>Telescope live_grep<CR>', { desc = 'Telescope search in files' })

-- Ripgrep search with prompt
vim.keymap.set('n', '\\A', ':Telescope grep_string search=', { desc = 'Ripgrep search with prompt' })

-- Telescope file finder
vim.keymap.set('n', '\\t', '<cmd>Telescope find_files<CR>', { desc = 'Find files' })

-- Copy file path (absolute)
vim.keymap.set('n', '\\c', function()
  local path = vim.fn.expand('%:p')
  vim.fn.setreg('+', path)
  print('File path copied to clipboard: ' .. path)
end, { desc = 'Copy absolute file path' })

-- Copy file path (relative)
vim.keymap.set('n', '\\r', function()
  local path = vim.fn.expand('%')
  vim.fn.setreg('+', path)
  print('Relative path copied to clipboard: ' .. path)
end, { desc = 'Copy relative file path' })

-- Clear search highlights
vim.keymap.set('n', '\\ ', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlights' })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Capital command mappings to lowercase
vim.api.nvim_create_user_command('W', 'w', {})
vim.api.nvim_create_user_command('Q', 'q', {})
vim.api.nvim_create_user_command('E', 'e', {})
vim.api.nvim_create_user_command('WQ', 'wq', {})
vim.api.nvim_create_user_command('Wq', 'wq', {})