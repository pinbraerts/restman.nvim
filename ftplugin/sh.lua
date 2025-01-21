local restman = require("restman")
local buffer = vim.api.nvim_get_current_buf()
vim.keymap.set(
  "n",
  "<cr>",
  restman.execute_paragraph,
  { desc = "Execute current paragraph", nowait = true, silent = true, buffer = buffer }
)
