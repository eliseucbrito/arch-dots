return {
  -- Diffview: Incredible side-by-side interface for reviewing changed code
  {
    "sindrets/diffview.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
    },
  },

  -- Octo: GitHub PRs integration (perfect for approving/commenting without leaving Neovim)
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    config = function()
      require("octo").setup()
    end,
    keys = {
      { "<leader>op", "<cmd>Octo pr list<cr>", desc = "List GitHub PRs" },
      { "<leader>os", "<cmd>Octo pr search<cr>", desc = "Search GitHub PRs" },
    },
  },

  -- GitLab: Code Review integration specifically designed for Self-Hosted instances
  {
    "harrisoncramer/gitlab.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "stevearc/dressing.nvim", -- Creates beautiful floating input windows for your code review comments
    },
    -- Builds the local Go server required by the plugin to handle API requests asynchronously
    build = function()
      require("gitlab.server").build(true)
    end,
    config = function()
      require("gitlab").setup({
        -- Note: For self-hosted instances, it is highly recommended to configure
        -- the host URL and token via environment variables (GITLAB_URL and GITLAB_TOKEN)
        -- in your shell config, rather than hardcoding them here to avoid leaking credentials to Git.
      })
    end,
    keys = {
      { "<leader>gls", "<cmd>Gitlab summary<cr>", desc = "GitLab MR Summary" },
      { "<leader>glr", "<cmd>Gitlab review<cr>", desc = "GitLab Start Review" },
      { "<leader>gla", "<cmd>Gitlab approve<cr>", desc = "GitLab Approve MR" },
      { "<leader>glc", "<cmd>Gitlab create_comment<cr>", desc = "GitLab Comment on Line" },
      { "<leader>gln", "<cmd>Gitlab create_note<cr>", desc = "GitLab Note (General MR Comment)" },
    },
  },
}
