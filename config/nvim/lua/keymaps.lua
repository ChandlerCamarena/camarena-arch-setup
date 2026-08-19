-- keymaps.lua
local map = vim.keymap.set

-- Window navigation (vim keys)
map("n", "<C-h>", "<C-w>h")
map("n", "<C-l>", "<C-w>l")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")

-- Move lines up/down in visual mode
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

-- Keep cursor centered when scrolling
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")

-- Keep cursor centered on search
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- File tree
map("n", "<leader>e", ":Neotree toggle<CR>")

-- Telescope
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>")
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>")
map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>")

-- LSP (set in lsp config, listed here for reference)
-- gd  = go to definition
-- gr  = go to references
-- K   = hover docs
-- <leader>rn = rename
-- <leader>ca = code action
-- <leader>d  = show diagnostics

-- Clear search highlight
map("n", "<Esc>", ":noh<CR>")

-- Better paste (don't overwrite register)
map("x", "<leader>p", '"_dP')

-- Save
map("n", "<leader>w", ":w<CR>")
map("n", "<leader>q", ":q<CR>")
