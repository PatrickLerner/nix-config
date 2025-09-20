-- git.lua - Git integration

return {
  { -- Git related plugins
    'tpope/vim-fugitive',
    cmd = { 'Git', 'Gstatus', 'Gblame', 'Gpush', 'Gpull', 'Greview' },
    config = function()
      -- Custom function to get merge-base
      vim.cmd([[
        function! s:git_merge_base() abort
          let result = FugitiveExecute(['merge-base', 'origin/main', 'HEAD'])
          if v:shell_error == 0 && len(result.stdout) > 0
            return result.stdout[0]
          else
            " Fallback to origin/main if merge-base fails
            return 'origin/main'
          endif
        endfunction

        " Create Greview command
        command! -nargs=0 Greview execute 'Git difftool -y ' . s:git_merge_base()
      ]])
    end,
  },

  {
    'tpope/vim-rhubarb', -- GitHub integration for fugitive
    dependencies = 'tpope/vim-fugitive',
  },

  {
    'shumphrey/fugitive-gitlab.vim', -- GitLab integration for fugitive
    dependencies = 'tpope/vim-fugitive',
  },

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },
}