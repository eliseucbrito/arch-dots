return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- test new blink
  { import = "nvchad.blink.lazyspec" },

  {
  	"nvim-treesitter/nvim-treesitter",
  	opts = {
  		ensure_installed = {
  			"vim", "lua", "vimdoc",
       "html", "css"
  		},
  	},
  },

  { "ChmaraX/herdr-nvim", opts = {} },


   "nvim-lua/plenary.nvim",

   {
     "nvchad/ui",
      config = function()
        require "nvchad"
      end
   },

   {
      "nvchad/base46",
      lazy = true,
      build = function()
        require("base46").load_all_highlights()
      end,
   },

   "nvzone/volt", -- optional, needed for theme switcher
}
