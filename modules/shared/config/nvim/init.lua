-- init.lua - Main Neovim configuration entry point

-- Set <space> as the leader key
-- See `:help mapleader`
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed
vim.g.have_nerd_font = true

-- [[ Setting options ]]
require('config.options')

-- [[ Basic Keymaps ]]
require('config.keymaps')

-- [[ Install `lazy.nvim` plugin manager ]]
require('config.lazy')

-- [[ Configure and install plugins ]]
require('lazy').setup({
  spec = {
    { import = 'plugins' },
  },
  defaults = {
    lazy = false,
    version = false, -- always use the latest git commit
  },
  checker = {
    enabled = true,
    notify = true,
    frequency = 604800, -- check every 7 days (7 * 24 * 60 * 60)
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- [[ Configure Autocommands ]]
require('config.autocmds')