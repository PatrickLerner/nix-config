-- editor.lua - Editor enhancements

return {
  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    config = function() -- This is the function that runs, AFTER loading
      require('which-key').setup()

      -- Document existing key chains
      require('which-key').add {
        { '<leader>c', group = '[C]ode' },
        { '<leader>d', group = '[D]ocument' },
        { '<leader>r', group = '[R]ename' },
        { '<leader>s', group = '[S]earch' },
        { '<leader>w', group = '[W]orkspace' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      }
    end,
  },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [']quote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

    end,
  },

  -- "gc" to comment visual regions/lines
  { 'numToStr/Comment.nvim', opts = {} },

  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

  -- Useful for Unix file operations
  'tpope/vim-eunuch',

  -- Better file manager
  'tpope/vim-vinegar',

  -- Auto-create directories when needed
  'pbrisbin/vim-mkdir',

  -- Auto-close end statements
  'tpope/vim-endwise',

  -- Make . repeat work with plugins
  'tpope/vim-repeat',

  -- Fast file search with ag
  {
    'mileszs/ack.vim',
    config = function()
      if vim.fn.executable('ag') == 1 then
        vim.g.ackprg = 'ag --vimgrep --smart-case'
      end
    end,
  },

  -- Prettier auto-formatting
  {
    'prettier/vim-prettier',
    build = 'yarn install',
    ft = { 'javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'markdown', 'vue', 'html', 'yaml' },
    config = function()
      -- Auto-format on save for supported file types
      vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = { '*.js', '*.jsx', '*.mjs', '*.ts', '*.tsx', '*.less', '*.json', '*.graphql', '*.md', '*.vue', '*.html', '*.scss', '*.css', '*.yaml', '*.yml' },
        callback = function()
          -- Don't prettier on helm files
          if vim.bo.filetype == 'helm' then
            return
          end
          vim.cmd('PrettierAsync')
        end,
      })
    end,
  },

  -- Titlecase operator
  'christoomey/vim-titlecase',

  -- Rust support
  { 'rust-lang/rust.vim', ft = 'rust' },

  -- Terraform support
  { 'hashivim/vim-terraform', ft = 'terraform' },

  -- Helm charts support
  { 'towolf/vim-helm', ft = 'helm' },

  -- JSON with comments support
  { 'neoclide/jsonc.vim', ft = 'jsonc' },

  -- Markdown rendering
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = 'markdown',
    opts = {},
  },

  -- Startify replacement
  {
    'mhinz/vim-startify',
    config = function()
      vim.g.startify_lists = {
        { type = 'dir', header = { '   MRU ' .. vim.fn.getcwd() .. ':' } },
        { type = 'sessions', header = { '   Sessions' } },
        { type = 'bookmarks', header = { '   Bookmarks' } },
      }
      vim.g.startify_bookmarks = {
        '~/Projects',
        '~/Documents',
      }
    end,
  },

  -- Writing mode
  {
    'preservim/vim-pencil',
    cmd = { 'Pencil', 'PencilOff', 'PencilToggle' },
  },

  {
    'junegunn/goyo.vim',
    cmd = { 'Goyo' },
  },
}