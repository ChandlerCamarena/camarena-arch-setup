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
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    main = "nvim-treesitter",
    opts = {
      ensure_installed = { "lua", "typescript", "tsx", "cpp", "c", "bash", "json" },
      highlight        = { enable = true },
      indent           = { enable = true },
    },
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

  -- ── Comments ──────────────────────────────────────────
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },

})
