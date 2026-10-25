-- lsp.lua
-- Native nvim 0.11+ LSP config (no lspconfig framework). Servers come from
-- pacman (packages/base.txt, profiles/languages.txt), not Mason.

local caps = vim.tbl_deep_extend("force",
  vim.lsp.protocol.make_client_capabilities(),
  require("cmp_nvim_lsp").default_capabilities()
)

-- Error/warning text at the end of the line; 0.11+ only shows a sign by default
vim.diagnostic.config({
  virtual_text  = { spacing = 2, prefix = "●" },
  severity_sort = true,
  float         = { border = "rounded", source = true },
})

-- Keymaps on attach. References/rename/code action also have the 0.11
-- built-ins grr/grn/gra; a plain `gr` here would make those wait on timeout.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local map = function(k, f) vim.keymap.set("n", k, f, { buffer = ev.buf }) end
    map("gd",         vim.lsp.buf.definition)
    map("K",          vim.lsp.buf.hover)
    map("<leader>rn", vim.lsp.buf.rename)
    map("<leader>ca", vim.lsp.buf.code_action)
    map("<leader>d",  vim.diagnostic.open_float)

    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.name == "clangd" then
      -- Jump between foo.h and foo.cpp
      map("<leader>h", function()
        local params = vim.lsp.util.make_text_document_params(ev.buf)
        client:request("textDocument/switchSourceHeader", params, function(err, uri)
          if not err and uri then vim.cmd.edit(vim.uri_to_fname(uri)) end
        end, ev.buf)
      end)
    end
  end,
})

-- Lua (also covers Hyprland's hyprland.lua; `hl` is its global)
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

-- C/C++. Real projects want a compile_commands.json at the root
-- (cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON) so clangd knows the flags.
vim.lsp.config("clangd", {
  capabilities = caps,
  cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=never" },
  filetypes = { "c", "cpp", "objc", "objcpp" },
  root_markers = { "compile_commands.json", ".clangd", "CMakeLists.txt", ".git" },
})
vim.lsp.enable("clangd")

-- Python
vim.lsp.config("pyright", {
  capabilities = caps,
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.py", "requirements.txt", ".git" },
})
vim.lsp.enable("pyright")

-- Bash (runs shellcheck for diagnostics)
vim.lsp.config("bashls", {
  capabilities = caps,
  cmd = { "bash-language-server", "start" },
  filetypes = { "sh", "bash" },
})
vim.lsp.enable("bashls")

-- QML (Quickshell). qmlls ships with qt6-declarative, outside PATH;
-- quickshell writes a .qmlls.ini next to the config so imports resolve.
vim.lsp.config("qmlls", {
  capabilities = caps,
  cmd = { "/usr/lib/qt6/bin/qmlls" },
  filetypes = { "qml", "qmljs" },
  root_markers = { ".qmlls.ini", "shell.qml", ".git" },
})
vim.lsp.enable("qmlls")

-- Haskell (languages profile)
vim.lsp.config("hls", {
  capabilities = caps,
  cmd = { "haskell-language-server-wrapper", "--lsp" },
  filetypes = { "haskell", "lhaskell", "cabal" },
  -- Literal names only (no globs), so a lone foo.cabal falls back to .git
  root_markers = { "cabal.project", "stack.yaml", "package.yaml", "hie.yaml", ".git" },
})
vim.lsp.enable("hls")
