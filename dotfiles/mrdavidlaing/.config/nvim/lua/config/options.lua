-- Neovim options configuration

local opt = vim.opt

-- File handling settings
vim.opt.filetype = "on"

-- General
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.swapfile = false
opt.backup = false
opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
opt.undofile = true

-- UI
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.colorcolumn = "80"
opt.cursorline = true
opt.termguicolors = true

-- Search
opt.hlsearch = false
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Indentation
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Performance
opt.updatetime = 50
opt.timeoutlen = 500

-- File handling
opt.fileencoding = "utf-8"
opt.conceallevel = 0

-- Completion
opt.completeopt = { "menuone", "noselect" }
opt.shortmess:append("c")