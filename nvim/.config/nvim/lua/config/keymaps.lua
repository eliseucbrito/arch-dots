-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Buffer navigation
map("n", "<Tab>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })

-- Close current buffer
map("n", "<leader>c", "<cmd>bd<cr>", { desc = "Close current buffer" })

-- Splits
map("n", "<leader>v", "<cmd>vsplit<cr>", { desc = "Split vertical" })

-- Line end and Start
map("i", "<C-e>", "<End>", { desc = "Line end" })
map("i", "<C-a>", "<Home>", { desc = "Line start" })
map("n", "L", "$", { desc = "Line end" })
map("n", "H", "^", { desc = "Line start" })
