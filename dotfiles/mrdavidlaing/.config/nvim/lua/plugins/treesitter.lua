-- Treesitter configuration for better syntax highlighting

return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    priority = 900,
    dependencies = {
      "windwp/nvim-ts-autotag",
    },
    config = function()
      -- Re-enable filetype for Treesitter
      vim.cmd.filetype('plugin on')
      
      require("nvim-treesitter.configs").setup({
        highlight = {
          enable = true,
          use_languagetree = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        autotag = {
          enable = true,
        },
        ensure_installed = {
          "bash", "lua", "yaml", "markdown", "json",
          "vim", "vimdoc", "gitcommit", "nix",
          "terraform", "hcl", "go", "gomod", "gosum",
          "dockerfile",
        },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-space>",
            node_incremental = "<C-space>",
            scope_incremental = false,
            node_decremental = "<bs>",
          },
        },
      })
    end,
  },
}