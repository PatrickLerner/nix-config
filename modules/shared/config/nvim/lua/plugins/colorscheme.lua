-- colorscheme.lua - Nord color scheme configuration

return {
  {
    'nordtheme/vim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    init = function()
      -- Load the colorscheme here.
      vim.cmd.colorscheme 'nord'
    end,
  },
}