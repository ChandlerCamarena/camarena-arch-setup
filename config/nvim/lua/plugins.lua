-- plugins.lua
local theme = require("theme-colors")

require("lazy").setup({

  -- ── Colorscheme ──────────────────────────────────────
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "night",
        transparent = true,
        terminal_colors = true,
        styles = {
          comments    = { italic = true },
          keywords    = { italic = false },
          sidebars    = "transparent",
          floats      = "transparent",
        },
        on_highlights = function(hl, c)
          -- Keywords: purple
          hl["@keyword"]          = { fg = theme.purple }
          hl["@keyword.function"] = { fg = theme.purple }
          hl["@keyword.return"]   = { fg = theme.coral }
          hl["@keyword.import"]   = { fg = theme.purple }
          hl["Keyword"]           = { fg = theme.purple }
          -- Functions: coral
          hl["@function"]         = { fg = theme.coral }
          hl["@function.call"]    = { fg = theme.coral }
          hl["@method"]           = { fg = theme.coral }
          hl["@method.call"]      = { fg = theme.coral }
          hl["Function"]          = { fg = theme.coral }
          -- Types: cyan (rare)
          hl["@type"]             = { fg = theme.cyan }
          hl["@type.builtin"]     = { fg = theme.cyan }
          hl["Type"]              = { fg = theme.cyan }
          -- Strings: amber
          hl["@string"]           = { fg = theme.warning }
          hl["String"]            = { fg = theme.warning }
          -- Numbers: coral
          hl["@number"]           = { fg = theme.coral }
          hl["@boolean"]          = { fg = theme.coral }
          -- Variables: neutral fg
          hl["@variable"]         = { fg = theme.fg }
          hl["@parameter"]        = { fg = theme.fg }
          hl["@field"]            = { fg = theme.fg }
          hl["@property"]         = { fg = theme.fg }
          -- Operators and punctuation: dim
          hl["@operator"]         = { fg = theme.fg_dim }
          hl["@punctuation"]      = { fg = theme.fg_dim }
          -- Comments: subtle
          hl["@comment"]          = { fg = theme.fg_subtle, italic = true }
          hl["Comment"]           = { fg = theme.fg_subtle, italic = true }
          -- Diagnostics
          hl["DiagnosticError"]   = { fg = theme.error }
          hl["DiagnosticWarn"]    = { fg = theme.warning }
          hl["DiagnosticInfo"]    = { fg = theme.cyan }
          hl["DiagnosticHint"]    = { fg = theme.purple }
        end,
        on_colors = function(c)
          -- Backgrounds
          c.bg               = theme.bg
          c.bg_dark          = theme.bg
          c.bg_float         = theme.bg_float
          c.bg_highlight     = theme.bg_highlight
          c.bg_sidebar       = theme.bg
          c.bg_statusline    = theme.bg
          -- Text
          c.fg               = theme.fg
          c.fg_dark          = theme.fg_dim
          c.fg_gutter        = theme.fg_subtle
          c.comment          = theme.fg_subtle
          -- Kill the neon blues -- remap to neutral or palette colors
          c.blue             = theme.fg       -- was neon blue, now neutral fg
          c.blue0            = theme.purple   -- deep blue -> purple
          c.blue1            = theme.fg
          c.blue2            = theme.fg
          c.blue5            = theme.fg_dim   -- muted
          c.blue6            = theme.fg_dim
          c.blue7            = theme.bg_highlight
          c.cyan             = theme.cyan     -- keep cyan but it'll be rare
          -- Accents
          c.purple           = theme.purple   -- keywords
          c.magenta          = theme.purple   -- also keywords
          c.magenta2         = theme.coral    -- coral for strong accents
          c.red              = theme.coral
          c.red1             = theme.coral
          c.orange           = theme.warning
          c.yellow           = theme.warning
          c.green            = theme.fg       -- was green, now neutral
          c.green1           = theme.cyan     -- teal for strings
          c.green2           = theme.cyan
          c.teal             = theme.cyan
          -- Borders
          c.border           = theme.bg_highlight
          c.border_highlight = theme.coral
        end,
      })
      vim.cmd("colorscheme tokyonight")
    end,
  },

  -- ── Statusline ───────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = {
            normal = {
              a = { bg = theme.coral, fg = theme.bg, gui = "bold" },
              b = { bg = theme.bg_highlight, fg = theme.fg },
              c = { bg = theme.bg, fg = theme.fg_dim },
            },
            insert = {
              a = { bg = theme.cyan, fg = theme.bg, gui = "bold" },
              b = { bg = theme.bg_highlight, fg = theme.fg },
              c = { bg = theme.bg, fg = theme.fg_dim },
            },
            visual = {
              a = { bg = theme.purple, fg = theme.bg, gui = "bold" },
              b = { bg = theme.bg_highlight, fg = theme.fg },
              c = { bg = theme.bg, fg = theme.fg_dim },
            },
            replace = {
              a = { bg = theme.error, fg = theme.bg, gui = "bold" },
              b = { bg = theme.bg_highlight, fg = theme.fg },
              c = { bg = theme.bg, fg = theme.fg_dim },
            },
            command = {
              a = { bg = theme.warning, fg = theme.bg, gui = "bold" },
              b = { bg = theme.bg_highlight, fg = theme.fg },
              c = { bg = theme.bg, fg = theme.fg_dim },
            },
          },
          component_separators = { left = "", right = "" },
          section_separators   = { left = "", right = "" },
          globalstatus = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "encoding", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })
    end,
  },

  -- ── File tree ─────────────────────────────────────────
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
        close_if_last_window = true,
        window = {
          width = 30,
          mappings = {
            ["<space>"] = "none",
          },
        },
        default_component_configs = {
          git_status = {
            symbols = {
              added     = "+",
              modified  = "~",
              deleted   = "-",
              renamed   = "r",
              untracked = "?",
              ignored   = "i",
              unstaged  = "u",
              staged    = "s",
              conflict  = "c",
            },
          },
        },
        filesystem = {
          filtered_items = {
            hide_dotfiles   = false,
            hide_gitignored = false,
          },
        },
      })
    end,
  },

  -- ── Fuzzy finder ─────────────────────────────────────
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          prompt_prefix   = "  ",
          selection_caret = " ",
          layout_config   = { prompt_position = "top" },
          sorting_strategy = "ascending",
        },
      })
      require("telescope").load_extension("fzf")
    end,
  },

  -- ── Treesitter (syntax highlighting) ─────────────────
  -- The `main` branch is a rewrite: no ensure_installed/highlight/indent
  -- options anymore. Parsers are installed explicitly (compiled with
  -- tree-sitter-cli, from base.txt) and highlighting is started per buffer.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "bash", "c", "cpp", "haskell", "json", "lua", "markdown",
        "markdown_inline", "python", "qmljs", "query", "tsx", "typescript",
        "vim", "vimdoc",
      })
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          -- pcall: filetypes without an installed parser just keep vim syntax
          if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  -- ── Autocomplete ─────────────────────────────────────
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp     = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"]   = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })

      -- Load native LSP config after cmp is ready
      require("lsp")
    end,
  },

  -- ── Git signs ─────────────────────────────────────────
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        signs = {
          add          = { text = "+" },
          change       = { text = "~" },
          delete       = { text = "-" },
          topdelete    = { text = "-" },
          changedelete = { text = "~" },
        },
      })
    end,
  },

  -- ── Indent guides ─────────────────────────────────────
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    config = function()
      require("ibl").setup({
        indent = { char = "▏" },
        scope  = { enabled = true },
      })
    end,
  },

  -- ── Autopairs ─────────────────────────────────────────
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({})
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },

  -- Comments: built in since nvim 0.10 (gc / gcc), no plugin needed.

  -- ── Keymap hints ──────────────────────────────────────
  -- Press <leader> (or g, ], z, ...) and wait: lists what can follow.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>c", group = "code" },
        { "<leader>r", group = "rename" },
      },
    },
  },

  -- ── Format on save ────────────────────────────────────
  -- Formatters come from pacman (clang-format ships with clang; ruff,
  -- stylua, shfmt in base.txt). Indent args match the repo's own style
  -- (4-space bash, 2-space Lua) instead of the tools' tab defaults.
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    opts = {
      formatters_by_ft = {
        c      = { "clang-format" },
        cpp    = { "clang-format" },
        python = { "ruff_format" },
        lua    = { "stylua" },
        sh     = { "shfmt" },
        bash   = { "shfmt" },
      },
      formatters = {
        shfmt  = { prepend_args = { "-i", "4", "-ci" } },
        stylua = { prepend_args = { "--indent-type", "Spaces", "--indent-width", "2" } },
      },
      -- Anything not listed above falls back to its language server
      format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
    },
  },

  -- ── Debugger (C/C++) ──────────────────────────────────
  -- gdb 14+ speaks the Debug Adapter Protocol natively (gdb -i dap), so no
  -- separate adapter to install. Build with -g first.
  {
    "mfussenegger/nvim-dap",
    dependencies = { "rcarriga/nvim-dap-ui", "nvim-neotest/nvim-nio" },
    keys = {
      { "<F5>",      function() require("dap").continue() end,          desc = "Debug: start/continue" },
      { "<F10>",     function() require("dap").step_over() end,         desc = "Debug: step over" },
      { "<F11>",     function() require("dap").step_into() end,         desc = "Debug: step into" },
      { "<F12>",     function() require("dap").step_out() end,          desc = "Debug: step out" },
      { "<leader>b", function() require("dap").toggle_breakpoint() end, desc = "Debug: toggle breakpoint" },
      { "<leader>B", function()
          require("dap").set_breakpoint(vim.fn.input("Condition: "))
        end, desc = "Debug: conditional breakpoint" },
      { "<leader>D", function() require("dapui").toggle() end,          desc = "Debug: toggle UI" },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dap.adapters.gdb = {
        type    = "executable",
        command = "gdb",
        args    = { "--interpreter=dap", "--eval-command", "set print pretty on" },
      }
      dap.configurations.c = {
        {
          name    = "Launch executable",
          type    = "gdb",
          request = "launch",
          program = function()
            return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd     = "${workspaceFolder}",
        },
      }
      dap.configurations.cpp = dap.configurations.c

      dapui.setup()
      dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"]     = function() dapui.close() end
    end,
  },

  -- ── Yazi in a float ───────────────────────────────────
  {
    "mikavilpas/yazi.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>-", "<cmd>Yazi<cr>", desc = "Yazi at current file" },
    },
    opts = {},
  },

})
