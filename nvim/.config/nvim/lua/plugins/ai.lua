return {
  { import = "lazyvim.plugins.extras.coding.copilot" },
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "hrsh7th/nvim-cmp",
    },
    config = function()
      require("codecompanion").setup({
        strategies = {
          chat = { adapter = "gemini" },
          inline = { adapter = "copilot" },
        },
        adapters = {
          gemini = function()
            return require("codecompanion.adapters").extend("gemini", {
              env = {
                api_key = "CMD: cat ~/.config/gemini_api_key",
              },
            })
          end,
        },
      })
    end,
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle AI Chat" },
      { "<leader>ap", "<cmd>CodeCompanionActions<cr>", desc = "AI Prompt Actions" },
    },
  },
}
