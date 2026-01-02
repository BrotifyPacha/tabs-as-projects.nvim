
vim.cmd [[
  set runtimepath+=.
  set runtimepath+=~/.local/share/nvim/site/pack/packer/start/plenary.nvim
  set runtimepath+=~/.local/share/nvim/site/pack/packer/start/telescope.nvim
]]

local tabs_as_projects = require("tabs-as-projects")

vim.keymap.set("n", "<F1><F1>", tabs_as_projects.pick_project({
  search_dirs = {
    { category = "home", path = "~" },
  },
}))

-- always show tabline
vim.o.showtabline = 2
vim.o.tabline = "%{%v:lua.require('tabs-as-projects.ui').tabline()%}"

-- herlper mappings
vim.keymap.set("n", "<space>tt", "<cmd>tabnew<cr>")
vim.keymap.set("n", "[[", "<cmd>tabprev<cr>")
vim.keymap.set("n", "]]", "<cmd>tabnext<cr>")
