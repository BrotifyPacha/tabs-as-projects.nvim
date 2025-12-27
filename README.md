# tabs-as-projects.nvim


A Neovim plugin that helps treat tabs as projects by providing a
telescope-based project picker and a custom tabline that displays working
directories.

> **Note**: This plugin was extracted from my personal Neovim config, so it's
> opinionated by design.

## Table of Contents

[[_toc_]]

## Features

- **Project Picker**: Telescope-based fuzzy finder for quickly opening projects
  - Search across multiple configured directories
  - Categorize projects for better organization
  - Customizable path display (show last N parts of the path)
  - Smart tab creation (creates new tab only if current tab has content)
  - Configurable directory listing function

- **Custom Tabline**: Visual representation of tabs as projects
  - Displays working directory name(s) for each tab
  - Supports multiple working directories per tab (window-local cwd)
  - Highlights current directory in bold
  - Custom color scheme that adapts to your colorscheme
  - Clean visual separators between tabs

## Installation

Requirements:
- Neovim >= 0.9.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- `find` command (typically pre-installed on Unix-like systems)


<details>
<summary>Using lazy.nvim</summary>

```lua
{
  "brotifypacha/tabs-as-projects.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()

    -- 1. Enable tabline (use `:help 'showtabline'` for more details)
    vim.opt.showtabline = 2

    -- 2. Use plugin-provided tabline
    vim.opt.tabline = "%!v:lua.require('tabs-as-projects.ui').tabline()"

    -- 3. Create a keymap for the project picker
    local tabs_as_projects = require("tabs-as-projects")
    local search_dirs = {
      { path = "~/workspace", category = "main" },
      { path = "~/projects", category = "side" },
      { path = "~/.config", category = "config" },
    }

    vim.keymap.set("n", "<F1><F1>", tabs_as_projects.pick_project({ search_dirs = search_dirs, pick_cmd = "tcd" }))
    vim.keymap.set("n", "<F1>l",    tabs_as_projects.pick_project({ search_dirs = search_dirs, pick_cmd = "lcd" }))

  end,
}
```

</details>

<details>
<summary>Using packer.nvim</summary>

```lua
use {
  "brotifypacha/tabs-as-projects.nvim",
  requires = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()

    -- 1. Enable tabline (use `:help 'showtabline'` for more details)
    vim.opt.showtabline = 2

    -- 2. Use plugin-provided tabline
    vim.opt.tabline = "%!v:lua.require('tabs-as-projects.ui').tabline()"

    -- 3. Create a keymap for the project picker
    local tabs_as_projects = require("tabs-as-projects")
    local search_dirs = {
      { path = "~/workspace", category = "main" },
      { path = "~/projects", category = "side" },
      { path = "~/.config", category = "config" },
    }

    vim.keymap.set("n", "<F1><F1>", tabs_as_projects.pick_project({ search_dirs = search_dirs, pick_cmd = "tcd" }))
    vim.keymap.set("n", "<F1>l",    tabs_as_projects.pick_project({ search_dirs = search_dirs, pick_cmd = "lcd" }))

  end,
}
```

</details>

<details>
<summary>Using vim.pack (Neovim v0.12+)</summary>

First, clone the repository:

```bash
git clone https://github.com/brotifypacha/tabs-as-projects.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/tabs-as-projects.nvim
```

Then add to your `init.lua`:

```lua
-- Enable the custom tabline
vim.opt.tabline = "%!v:lua.require('tabs-as-projects.ui').tabline()"

-- Setup project picker with your configuration
local pick_project = require("tabs-as-projects").pick_project

vim.keymap.set("n", "<leader>fp", function()
  pick_project({
    search_dirs = {
      { path = "~/workspace/personal", category = "personal" },
      { path = "~/workspace/work", category = "work" },
    },
    pick_cmd = "tcd", -- or "cd", "lcd"
  })
end, { desc = "Pick project" })
```

</details>

## Configuration

### Example Setup

```lua

-- 1. Enable tabline (use `:help 'showtabline'` for more details)
vim.opt.showtabline = 2

-- 2. Use plugin-provided tabline
vim.opt.tabline = "%!v:lua.require('tabs-as-projects.ui').tabline()"

-- 3. Create a keymap for the project picker
local tabs_as_projects = require("tabs-as-projects")
local search_dirs = {
  { path = "~/workspace", category = "main" },
  { path = "~/projects", category = "side" },
  { path = "~/.config", category = "config" },
}

vim.keymap.set("n", "<F1><F1>", tabs_as_projects.pick_project({ search_dirs = search_dirs, pick_cmd = "tcd" }))
vim.keymap.set("n", "<F1>l",    tabs_as_projects.pick_project({ search_dirs = search_dirs, pick_cmd = "lcd" }))
```

### Configuration Options

```lua

require("tabs-as-projects").pick_project({

  -- (list of directory configs, required)
  search_dirs = {
    {
      -- (string, required) - Path to search project directories in
      path = "~/workspace",

      -- (string, optional) A label to categorize projects (if present, displayed in picker)
      category = "work",

      -- (integer, optional, default: 2): Number of path parts to show in picker
      -- for example given an absolute project path /User/example/workspace/project-a
      -- value 1 will display such path as: project-a
      -- value 2 will display such path as: workspace/project-a
      -- value 3 will display such path as: example/workspace/project-a
      -- and so on
      display_path_parts = 2,
    },
  },

  -- (string, optional, default: "tcd") - ex command to use when user picks a project
  pick_cmd = "tcd"

  -- (fun(path: string) string[], optional) - Function to list directories with
  list_dir = require("tabs-as-projects.list_dir_fn").find_list_dir
})

```

### Advanced

#### Custom `list_dir` implementation

If for some reason, default `find_list_dir` doesn't suit your needs, you can
create your own using a helper function `list_using_cmd`:

```lua
local list_dir_fn = require("tabs-as-projects.list_dir_fn")

pick_project({
  search_dirs = { --[[ ... ]] },
  -- The '%s' will be substituted by 'path' argument of your configured 'search_dirs'.
  list_dir = list_dir_fn.list_using_cmd('fd --type d --max-depth 1 . "%s"'),
})
```

Or create your create your own from scratch:

```lua
--- @param path string
--- @return string[]
local function my_custom_list_dir(path)
  -- Your custom logic here
  -- Return an array of absolute directory paths
  return {
    path .. "/project1",
    path .. "/project2",
  }
end

pick_project({
  search_dirs = { --[[ ... ]] },
  list_dir = my_custom_list_dir,
})
```

#### Customizing Colors

The tabline uses highlight groups that you can customize:

- `TabProjects_Tab` - Inactive tab (links to `Tabline` by default)
- `TabProjects_TabSelected` - Active tab (links to `Normal` by default)
- `TabProjects_TabSelectedBold` - Current directory in active tab (bold)
- `TabProjects_Divider` - Separator between tabs
- `TabProjects_DividerSelected` - Separator adjacent to active tab

Example customization:

```lua
-- vim.o.tabline = ...

-- Should be used after tabline setup
vim.api.nvim_set_hl(0, "TabProjects_TabSelected", { bg = "#1e1e2e", fg = "#cdd6f4" })
vim.api.nvim_set_hl(0, "TabProjects_TabSelectedBold", { bg = "#1e1e2e", fg = "#cdd6f4", bold = true })
```

## Health Check

Run `:checkhealth tabs-as-projects` to verify:
- Telescope is installed
- Required binaries (`find`) are available

## License

MIT
