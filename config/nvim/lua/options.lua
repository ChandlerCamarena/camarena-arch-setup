-- options.lua
local o = vim.opt

-- Line numbers
o.number         = true
o.relativenumber = true

-- Indentation
o.tabstop        = 2
o.shiftwidth     = 2
o.expandtab      = true
o.smartindent    = true

-- Search
o.ignorecase     = true
o.smartcase      = true
o.hlsearch       = false
o.incsearch      = true

-- Appearance
o.termguicolors  = true
o.signcolumn     = "yes"
o.cursorline     = true
o.scrolloff      = 8
o.wrap           = false

-- Splits
o.splitbelow     = true
o.splitright     = true

-- Misc
o.updatetime     = 250
o.undofile       = true
o.clipboard      = "unnamedplus"
o.mouse          = "a"
o.showmode       = false
