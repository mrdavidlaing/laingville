-- Lazygit integration for nvim
-- Optimized for AI monitoring workflow with WezTerm/tmux

return {
  "kdheepak/lazygit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  keys = {
    -- Primary lazygit access
    { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    { "<leader>lG", "<cmd>LazyGitCurrentFile<cr>", desc = "LazyGit (current file)" },
    { "<leader>lc", "<cmd>LazyGitConfig<cr>", desc = "LazyGit Config" },
  },
  config = function()
    -- Configure lazygit.nvim for optimal AI monitoring workflow
    vim.g.lazygit_floating_window_winblend = 0 -- transparency of floating window
    vim.g.lazygit_floating_window_scaling_factor = 0.9 -- scaling factor for floating window
    vim.g.lazygit_floating_window_border_chars = { '╭','─', '╮', '│', '╯','─', '╰', '│' } -- customize lazygit popup window border characters
    vim.g.lazygit_floating_window_use_plenary = 0 -- use plenary.nvim to manage floating window if available
    vim.g.lazygit_use_neovim_remote = 1 -- enable neovim-remote support for commit editing
    
    -- Configure to use system lazygit config
    vim.g.lazygit_use_custom_config_file_path = 0
    
    -- Auto-close lazygit after certain actions (useful for quick commits)
    -- vim.g.lazygit_floating_window_corner_chars = {'╭', '╮', '╯', '╰'}
  end
}