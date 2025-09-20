-- ale.lua - ALE linting configuration

return {
  {
    'dense-analysis/ale',
    config = function()
      -- ALE configuration
      vim.g.ale_open_list = 0
      vim.g.ale_lint_on_text_changed = 'never'
      vim.g.ale_linters = {
        ruby = { 'rubocop' },
        -- Add other linters as needed
      }

      -- Custom signs
      vim.g.ale_sign_error = '!'
      vim.g.ale_sign_warning = '?'

      -- Highlight linking
      vim.cmd('highlight link ALEErrorSign Error')
      vim.cmd('highlight link ALEWarningSign Warning')
    end,
  },
}