-- Telescope fuzzy finder configuration

return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.5",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")

      telescope.setup({
        defaults = {
          path_display = { "truncate" },
          mappings = {
            i = {
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-j>"] = actions.move_selection_next,
              ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
            },
          },
        },
      })

      telescope.load_extension("fzf")

      -- Set keymaps
      local keymap = vim.keymap

      keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
      keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
      keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
      keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
      keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Show open buffers" })
      keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Show available help tags" })
      keymap.set("n", "<leader>fm", "<cmd>Telescope marks<cr>", { desc = "Show marks" })
      keymap.set("n", "<leader>fk", "<cmd>Telescope keymaps<cr>", { desc = "Show keymaps" })
      keymap.set("n", "<leader>gc", "<cmd>Telescope git_commits<cr>", { desc = "Show git commits" })
      keymap.set("n", "<leader>gf", "<cmd>Telescope git_bcommits<cr>", { desc = "Show git commits for current buffer" })
      keymap.set("n", "<leader>gb", "<cmd>Telescope git_branches<cr>", { desc = "Show git branches" })
      keymap.set("n", "<leader>gs", "<cmd>Telescope git_status<cr>", { desc = "Show current git changes" })
    end,
  },
}