-- Which-key for displaying available keybindings

return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 500
    end,
    config = function()
      local wk = require("which-key")

      wk.setup({
        preset = "modern",
        plugins = { 
          spelling = true,
        },
      })

      wk.add({
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>s", group = "split" },
        { "<leader>t", group = "tab" },
        { "<leader>c", group = "code" },
      })
    end,
  },
}