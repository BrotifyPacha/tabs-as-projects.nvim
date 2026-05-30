local M = {}

local function select(cmd)

  local action_state = require "telescope.actions.state"
  local actions = require "telescope.actions"

  return function(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)

    local selected = {}
    for _, entry in ipairs(picker:get_multi_selection()) do
      selected[#selected+1] = entry.value
    end

    if #selected == 0 then
      selected[#selected+1] = action_state.get_selected_entry().value
    end

    actions.close(prompt_bufnr)


    local win_list = vim.api.nvim_tabpage_list_wins(0)
    local tab_win = vim.api.nvim_tabpage_get_win(0)
    local bufname = vim.fn.bufname(vim.api.nvim_win_get_buf(tab_win))

    local current_tab_not_empty = #win_list > 1 or bufname ~= ''

    if cmd == "tcd" and current_tab_not_empty then
      vim.cmd("tabnew")
    end

    for i, project_path in ipairs(selected) do

      if i > 1 then
        if cmd == "tcd" then
          cmd = "tabnew | tcd"
        end
        if cmd == "lcd" then
          cmd = "split | lcd"
        end
      end

      vim.cmd( cmd .. ' ' .. project_path )

    end
  end
end

--- @alias attach_mappings_fn fun(prompt_bufnr, map): boolean

M.select_tab_project = select("tcd")

M.select_local_project = select("lcd")

--- @class pick_project_options
--- @field search_dirs search_dir_config[]
--- @field list_dir list_dir_fn|nil
--- @field mappings attach_mappings_fn|nil
---
--- @class search_dir_config
--- @field path string
--- @field category string|nil
--- @field display_path_parts integer|nil
--- @field detect_git_worktrees boolean|nil

--- @param opts pick_project_options
function M.pick_project(opts)

  local dirs = opts.search_dirs

  local list_dir = require("tabs-as-projects.list_dir_fn").find_list_dir
  if opts.list_dir ~= nil then
    list_dir = opts.list_dir
  end

  --- @class project_picker_item
  --- @field absolute_path string
  --- @field display_text string

  --- @type project_picker_item[]
  local resultList = {}

  for _, dir in ipairs(dirs) do

    local absolute_dir_path = vim.fn.expand(dir.path)

    local paths = list_dir(absolute_dir_path)

    for _, path in ipairs(paths) do

      if path == absolute_dir_path then
        goto continue
      end

      local display_text = {}

      if dir.category ~= "" then
        display_text[#display_text+1] = string.format("(%s)", dir.category)
      end

      local util = require("tabs-as-projects.util")

      local path_parts = vim.split(path, "/")
      local last_n_parts = util.slice(
        path_parts,
        #path_parts - ((dir.display_path_parts or 2) - 1),
        #path_parts
      )

      display_text[#display_text+1] = table.concat(last_n_parts, "/")

      if dir.detect_git_worktrees ~= nil and dir.detect_git_worktrees then

        local worktrees = require("tabs-as-projects.git_worktrees").list(path)

        if #worktrees > 0 then
          for _, worktree in ipairs(worktrees) do
            local worktree_display_text = table.concat(display_text, " ") .. " (" .. worktree.branch .. ")"
            resultList[#resultList+1] = {
              absolute_path = worktree.absolute_path,
              display_text = worktree_display_text,
            }
          end
          goto continue
        end
      end

      resultList[#resultList+1] = {
        absolute_path = path,
        display_text = table.concat(display_text, " "),
      }
      ::continue::
    end
  end

  local actions = require "telescope.actions"
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local sorters = require "telescope.sorters"
  local dropdown = require "telescope.themes".get_dropdown()

  local attach_mappings_fn = function (_, map)
    map("n", "<TAB>", actions.toggle_selection)
    map("i", "<TAB>", actions.toggle_selection)
    map("n", "<CR>",  M.select_tab_project)
    map("i", "<CR>",  M.select_tab_project)
    map("n", "<C-l>", M.select_local_project)
    map("i", "<C-l>", M.select_local_project)
    return true
  end
  if opts.mappings ~= nil then
    attach_mappings_fn = opts.mappings
  end

  local opts = {
    prompt_title = "Pick project",
    finder = finders.new_table({
      results = resultList,
      entry_maker = function(item)

        --- @type project_picker_item
        local item = item

        return {
          display = item.display_text,
          value = item.absolute_path,
          ordinal = item.absolute_path,
        }
      end
    }),
    sorter = sorters.get_generic_fuzzy_sorter({}),
    attach_mappings = attach_mappings_fn,
  }

  local dir_picker = pickers.new(dropdown, opts)

  dir_picker:find()
end

return M
