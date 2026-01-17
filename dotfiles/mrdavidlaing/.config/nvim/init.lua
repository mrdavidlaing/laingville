-- Neovim configuration for mrdavidlaing
-- Part of Laingville family network dotfiles

-- Prevent E1155 autocommand errors
vim.cmd.syntax('off')
vim.cmd.filetype('off')

-- Disable netrw to avoid conflicts with file managers
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Bootstrap lazy.nvim plugin manager  
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load core configuration
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Setup plugins with LazyVim
require("lazy").setup({
  spec = {
    -- LazyVim core must come first
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Then your own plugins
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false,
  },
  change_detection = {
    notify = false,
  },
  rocks = {
    enabled = false,
  },
})