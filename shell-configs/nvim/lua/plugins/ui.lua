return {
  -- catppuccin: warm pastel theme (mocha variant, matching kitty terminal)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      integrations = {
        gitsigns = true,
        neogit = true,
        diffview = true,
        telescope = { enabled = true },
        treesitter = true,
        which_key = true,
        neotree = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },

  -- lualine.nvim: statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "catppuccin",
        globalstatus = true,
      },
    },
  },

  -- neo-tree.nvim: file explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    cmd = "Neotree",
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file explorer" },
    },
    opts = {
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
      },
    },
  },

  -- which-key.nvim: keybinding hints popup
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- nvim-web-devicons: file type icons
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },

  -- nui.nvim: UI component library (dependency for multiple plugins)
  {
    "MunifTanjim/nui.nvim",
    lazy = true,
  },

  -- plenary.nvim: Lua utility library (dependency for multiple plugins)
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
}
