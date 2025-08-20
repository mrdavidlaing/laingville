-- Neovim configuration for mrdavidlaing
-- Part of Laingville family network dotfiles

-- Prevent E1155 autocommand errors
vim.cmd.syntax('off')
vim.cmd.filetype('off')

-- Disable netrw to avoid conflicts with file managers
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Ensure we're using the correct data directory (not config dir)
-- This prevents issues with symlinked config directories
local data_dir = vim.fn.stdpath("data")
local config_dir = vim.fn.stdpath("config")

-- Debug: ensure paths are correct
if data_dir == config_dir then
  vim.notify("WARNING: data dir equals config dir - this will cause problems", vim.log.levels.ERROR)
end

-- Bootstrap lazy.nvim plugin manager
local lazypath = data_dir .. "/lazy/lazy.nvim"
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

-- Setup plugins
require("lazy").setup("plugins", {
  change_detection = {
    notify = false,
  },
})