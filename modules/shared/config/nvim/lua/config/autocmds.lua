-- autocmds.lua - Autocommands

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Remove trailing whitespace on save
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*',
  command = [[%s/\s\+$//e]],
})

-- Enter insert mode when switching to terminal
vim.api.nvim_create_autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('custom-term-open', { clear = true }),
  callback = function()
    vim.opt.number = false
    vim.opt.relativenumber = false
  end,
})

-- Automatically enter insert mode when focusing terminal
vim.api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter', 'TermOpen' }, {
  callback = function(args)
    if vim.startswith(vim.api.nvim_buf_get_name(args.buf), 'term://') then
      vim.cmd('startinsert')
    end
  end,
})

-- Close terminal with q
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'help', 'alpha', 'dashboard', 'neo-tree', 'Trouble', 'trouble', 'lazy', 'mason', 'notify', 'toggleterm', 'lazyterm' },
  callback = function()
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = true })
  end,
})

-- Set wrap and spell in markdown and gitcommit
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'gitcommit', 'markdown' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Disable the concealing in some file formats
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'json', 'jsonc', 'markdown' },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

-- Prevent accidentally saving files with typos in command
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = { '[:;\\\']*' },
  callback = function()
    vim.api.nvim_err_writeln('Forbidden file name: ' .. vim.fn.expand('<afile>'))
    return true -- prevent the write
  end,
})