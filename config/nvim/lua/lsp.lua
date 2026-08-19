-- lsp.lua
-- Native nvim 0.11+ LSP config (no lspconfig framework)

local caps = vim.tbl_deep_extend("force",
  vim.lsp.protocol.make_client_capabilities(),
  require("cmp_nvim_lsp").default_capabilities()
)

-- Keymaps on attach
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local map = function(k, f) vim.keymap.set("n", k, f, { buffer = ev.buf }) end
    map("gd",         vim.lsp.buf.definition)
    map("gr",         vim.lsp.buf.references)
    map("K",          vim.lsp.buf.hover)
    map("<leader>rn", vim.lsp.buf.rename)
    map("<leader>ca", vim.lsp.buf.code_action)
    map("<leader>d",  vim.diagnostic.open_float)
  end,
})

-- Lua
vim.lsp.config("lua_ls", {
  capabilities = caps,
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  settings = {
    Lua = {
      runtime     = { version = "LuaJIT" },
      diagnostics = { globals = { "vim", "hl" } },
      workspace   = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
      telemetry   = { enable = false },
    },
  },
})
vim.lsp.enable("lua_ls")

-- TypeScript
vim.lsp.config("ts_ls", {
  capabilities = caps,
  cmd = { "typescript-language-server", "--stdio" },
  filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
})
vim.lsp.enable("ts_ls")

-- C/C++
vim.lsp.config("clangd", {
  capabilities = caps,
  cmd = { "clangd" },
  filetypes = { "c", "cpp", "objc", "objcpp" },
})
vim.lsp.enable("clangd")
