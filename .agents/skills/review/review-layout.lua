-- Review layout: the report on the left window, code targets open on the right.
-- Launch with the report as the file arg:  nvim -c 'luafile <this>' <report>
-- gf  opens the file under the cursor in the RIGHT window.
-- gF  opens it at the trailing :line, if present.
-- The report window is never replaced, so you keep it open and browse in the other.

-- This is a read-only report view: silence diagnostics (markdownlint line-length
-- noise) so the rendered markdown stays clean.
vim.diagnostic.enable(false)

local report_win = vim.api.nvim_get_current_win()
vim.cmd("botright vsplit | enew") -- right window, empty scratch
local target_win = vim.api.nvim_get_current_win()
vim.api.nvim_set_current_win(report_win)

local function open_in_target(with_line)
  local cfile = vim.fn.expand("<cfile>")
  if cfile == "" then
    return
  end
  local line
  if with_line then
    local m = vim.fn.matchlist(vim.fn.getline("."), "\\V" .. vim.fn.escape(cfile, "\\") .. ":\\(\\d\\+\\)")
    line = m[2]
  end
  if not vim.api.nvim_win_is_valid(target_win) then
    vim.cmd("botright vsplit")
    target_win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(target_win)
  vim.cmd("edit " .. vim.fn.fnameescape(cfile))
  if line and line ~= "" then
    vim.cmd(tostring(line))
  end
  vim.api.nvim_set_current_win(report_win)
end

local report_buf = vim.api.nvim_win_get_buf(report_win)
vim.keymap.set("n", "gf", function()
  open_in_target(false)
end, { buffer = report_buf, desc = "review: open file under cursor in target window" })
vim.keymap.set("n", "gF", function()
  open_in_target(true)
end, { buffer = report_buf, desc = "review: open file:line under cursor in target window" })
