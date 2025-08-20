-- Colorscheme configuration - Solarized Dark matching WezTerm

return {
  {
    "maxmx03/solarized.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("solarized").setup({
        theme = "dark",
        transparent = {
          enabled = false,
        },
        styles = {
          comments = { italic = true },
          keywords = { bold = true },
          functions = {},
          variables = {},
          numbers = {},
          constants = {},
        },
        colors = {
          -- Match WezTerm solarized dark colors exactly
          base04 = "#002b36",  -- background
          base2 = "#eee8d5",   -- foreground
          orange = "#ff8800",  -- accent matching WezTerm selection
        },
        highlights = {
          -- Custom highlights to better match terminal
          Normal = { bg = "#002b36", fg = "#eee8d5" },
          NormalFloat = { bg = "#073642", fg = "#eee8d5" },
          FloatBorder = { bg = "#073642", fg = "#586e75" },
          SignColumn = { bg = "#002b36" },
          ColorColumn = { bg = "#073642" },
          CursorLine = { bg = "#073642" },
          Visual = { bg = "#ff8800", fg = "#002b36" },
          Search = { bg = "#b58900", fg = "#002b36" },
          IncSearch = { bg = "#ff8800", fg = "#002b36" },
        },
      })

      vim.cmd.colorscheme("solarized")
    end,
  },
}