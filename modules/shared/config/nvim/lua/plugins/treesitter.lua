-- treesitter.lua - Syntax highlighting and more (nvim-treesitter `main` branch)

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    lazy = false,
    config = function()
      local ts = require('nvim-treesitter')

      local ensure_installed = {
        'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline',
        'vim', 'vimdoc', 'javascript', 'typescript', 'tsx', 'json', 'yaml',
        'rust', 'python', 'go', 'ruby', 'query', 'regex',
      }

      ts.install(ensure_installed)

      vim.api.nvim_create_autocmd('FileType', {
        pattern = {
          'bash', 'sh', 'c', 'diff', 'html', 'lua', 'markdown',
          'vim', 'help', 'javascript', 'typescript', 'typescriptreact',
          'json', 'yaml', 'rust', 'python', 'go', 'ruby', 'query',
        },
        callback = function(args)
          local ft = vim.bo[args.buf].filetype
          local lang = vim.treesitter.language.get_lang(ft) or ft
          if not pcall(vim.treesitter.start, args.buf, lang) then
            return
          end
          if ft ~= 'ruby' then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'ruby',
        callback = function()
          vim.bo.syntax = 'ON'
        end,
      })
    end,
  },
}
