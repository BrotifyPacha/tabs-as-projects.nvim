
vim.cmd [[
  set runtimepath+=.
  set runtimepath+=~/.local/share/nvim/site/pack/packer/start/plenary.nvim
  set runtimepath+=~/.local/share/nvim/site/pack/packer/start/telescope.nvim
]]

vim.keymap.set("n", "<F1><F1>", function() require("tabs-as-projects").pick_project({
  search_dirs = {
    { category = "home", path = "~" },
  },
  pick_cmd = "tcd",
}) end)

-- always show tabline
vim.o.showtabline = 2
vim.o.tabline = "%{%v:lua.require('tabs-as-projects.ui').tabline()%}"
