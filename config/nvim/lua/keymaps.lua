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
map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>")  -- functions/classes in this file
map("n", "<leader>fd", "<cmd>Telescope diagnostics<cr>")           -- all errors/warnings
map("n", "<leader>/",  "<cmd>Telescope current_buffer_fuzzy_find<cr>")

-- Debugger: F5 start/continue, F10/F11/F12 step over/into/out,
-- <leader>b breakpoint, <leader>B conditional, <leader>D toggle UI (plugins.lua)
-- Yazi float: <leader>- (plugins.lua)
-- Comment: gcc line, gc{motion}/visual gc (built in)

-- LSP (set in lsp config, listed here for reference)
-- gd  = go to definition
-- grr = go to references (built in since 0.11, as are grn/gra/gri)
-- K   = hover docs
-- <leader>rn = rename
-- <leader>ca = code action
-- <leader>d  = show diagnostics
-- <leader>h  = switch header/source (C/C++, clangd)

-- Clear search highlight
map("n", "<Esc>", ":noh<CR>")

-- Better paste (don't overwrite register)
map("x", "<leader>p", '"_dP')

-- Save
map("n", "<leader>w", ":w<CR>")
map("n", "<leader>q", ":q<CR>")
