return {
  -- render-markdown.nvim: in-buffer markdown rendering. Tuned for reading (glow-like),
  -- not editing: raw syntax stays hidden even under the cursor, content is width-capped
  -- and centered, code blocks get a filled background with a language badge.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      -- Don't reveal raw markup on the cursor line/row — the biggest source of "noise".
      anti_conceal = { enabled = false },
      -- Cap the render width and center it, the way glow does in its pager.
      win_options = {
        showbreak = { default = "", rendered = "  " },
        breakindent = { default = false, rendered = true },
      },
      heading = {
        width = "block",
        min_width = 80,
        left_pad = 2,
        right_pad = 4,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      code = {
        width = "block",
        min_width = 80,
        left_pad = 2,
        right_pad = 2,
        border = "thick",
        style = "full", -- language badge + filled background
      },
      dash = { width = 80 },
      bullet = { icons = { "● ", "○ ", "◆ ", "◇ " } },
      checkbox = {
        checked = { icon = "󰄲 " },
        unchecked = { icon = "󰄱 " },
      },
    },
  },
}
