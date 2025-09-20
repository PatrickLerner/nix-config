-- lightline.lua - Lightline statusline configuration

return {
  {
    'itchyny/lightline.vim',
    dependencies = { 'dense-analysis/ale' },
    config = function()
      vim.g.lightline = {
        colorscheme = 'nord',
        component_function = {
          filename = 'LightlineFilename',
        },
        component_expand = {
          linter_checking = 'lightline#ale#checking',
          linter_warnings = 'lightline#ale#warnings',
          linter_errors = 'lightline#ale#errors',
          linter_ok = 'lightline#ale#ok',
        },
        component_type = {
          linter_checking = 'left',
          linter_warnings = 'warning',
          linter_errors = 'error',
          linter_ok = 'left',
        },
        active = {
          right = {
            { 'lineinfo' },
            { 'percent' },
            { 'fileformat', 'fileencoding', 'filetype' },
            { 'linter_checking', 'linter_errors', 'linter_warnings', 'linter_ok' }
          }
        }
      }

      -- Custom filename function to show context for certain files
      vim.api.nvim_exec([[
        function! LightlineFilename()
          let path = expand('%:p')
          let fn = expand('%:t')
          let dir = expand('%:p:h:h')

          if fn =~ '^index' || fn =~ '^mod.rs' || fn =~ '^tests.rs' || fn =~ '^main.yml'
            " also display folder name
            return path[len(dir)+1:]
          end

          return fn
        endfunction
      ]], false)
    end,
  },
}