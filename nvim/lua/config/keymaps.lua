-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", ";", ":", { noremap = true, silent = false })
vim.keymap.set("i", "jk", "<ESC>", { noremap = true, silent = true })

vim.keymap.set("n", "<Leader>hc", ":checkhealth<CR>", { noremap = true, silent = true })

-- Avante
vim.keymap.set("n", "<leader>ag", "<cmd>AvanteSwitchProvider gemini<cr>", { desc = "Switch to Gemini" })
vim.keymap.set("n", "<leader>ao", "<cmd>AvanteSwitchProvider ollama<cr>", { desc = "Switch to Ollama" })
