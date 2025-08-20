-- Keymaps configuration

local keymap = vim.keymap

-- Set leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- General keymaps
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- Clear search highlights
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- Delete without yanking
keymap.set("x", "<leader>p", [["_dP]], { desc = "Delete without yanking" })
keymap.set({"n", "v"}, "<leader>d", [["_d]], { desc = "Delete without yanking" })

-- Copy to system clipboard
keymap.set({"n", "v"}, "<leader>y", [["+y]], { desc = "Copy to system clipboard" })
keymap.set("n", "<leader>Y", [["+Y]], { desc = "Copy line to system clipboard" })

-- Window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

-- Tab management
keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" })

-- Move lines
keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selected lines down" })
keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selected lines up" })

-- Keep cursor centered
keymap.set("n", "J", "mzJ`z", { desc = "Join lines keeping cursor centered" })
keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Page down keeping cursor centered" })
keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Page up keeping cursor centered" })
keymap.set("n", "n", "nzzzv", { desc = "Next search result centered" })
keymap.set("n", "N", "Nzzzv", { desc = "Previous search result centered" })

-- Better indenting
keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Terminal
keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Manual Treesitter enable
keymap.set("n", "<leader>se", function()
  if pcall(require, "nvim-treesitter") then
    vim.cmd("TSBufEnable highlight")
    print("Treesitter highlighting enabled")
  end
end, { desc = "Enable syntax highlighting" })