return {
  {
    "atiladefreitas/dooing",
    event = "VeryLazy",
    -- Shared "Claude backlog": a separate JSON the AI assistant appends to via
    -- the `dooing-task` CLI. Open it with <leader>tc or :DooingClaude.
    keys = {
      { "<leader>tc", "<cmd>DooingClaude<cr>", desc = "Dooing: Claude backlog" },
    },
    config = function(_, opts)
      require("dooing").setup(opts)

      local claude_db = vim.fn.expand("~/.local/share/dooing/claude_backlog.json")

      local function open_claude_backlog()
        local state = require("dooing.state")
        local ui = require("dooing.ui")

        if vim.fn.filereadable(claude_db) == 0 then
          vim.fn.mkdir(vim.fn.fnamemodify(claude_db, ":h"), "p")
          local f = io.open(claude_db, "w")
          if f then
            f:write("[]")
            f:close()
          end
        end

        state.load_todos_from_path(claude_db)
        state.current_context = "Claude backlog"

        if ui.is_window_open() then
          require("dooing.ui.window").update_window_title()
          ui.render_todos()
        else
          ui.toggle_todo_window()
        end
      end

      -- Expose on the module so the Hyprland launcher can force-load and call it
      -- directly (`nvim -c "lua require('dooing').open_claude_backlog()"`).
      require("dooing").open_claude_backlog = open_claude_backlog

      vim.api.nvim_create_user_command("DooingClaude", open_claude_backlog, {
        desc = "Open the shared Claude backlog",
      })
    end,
    opts = {
      keymaps = {
        toggle_window = "<leader>td",
        new_todo = "i",
        toggle_todo = "x",
        delete_todo = "d",
        delete_completed = "D",
        close_window = "q",
        add_due_date = "H",
        remove_due_date = "r",
        toggle_help = "?",
        toggle_tags = "t",
        clear_filter = "c",
        edit_todo = "e",
        edit_tag = "e",
        delete_tag = "d",
        search_todos = "/",
      },
    },
  },
}
