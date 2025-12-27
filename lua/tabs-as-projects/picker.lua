local M = {}

--- @class pick_project_options
--- @field search_dirs search_dir_config[]
--- @field pick_cmd string
--- @field list_dir list_dir_fn|nil
---
--- @class search_dir_config
--- @field path string
--- @field category string|nil
--- @field display_path_parts integer|nil

--- @param opts pick_project_options
function M.pick_project(opts)

  local dirs = opts.search_dirs
  local cmd = opts.pick_cmd


  local list_dir = require("tabs-as-projects.list_dir_fn").find_list_dir
  if opts.list_dir ~= nil then
    list_dir = opts.list_dir
  end

  --- @class project_picker_item
  --- @field absolute_path string
  --- @field path_parts_to_display integer|nil
  --- @field category string|nil

  --- @type project_picker_item[]
  local resultList = {}

  for _, dir in ipairs(dirs) do

    local absolute_dir_path = vim.fn.expand(dir.path)

    local paths = list_dir(absolute_dir_path)

    for _, path in ipairs(paths) do

      if path == absolute_dir_path then
        goto continue
      end

      resultList[#resultList+1] = {
        absolute_path = path,
        path_parts_to_display = dir.display_path_parts,
        category = dir.category,
      }
      ::continue::
    end
  end

  local actions = require "telescope.actions"
  local actions_state = require "telescope.actions.state"
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local sorters = require "telescope.sorters"
  local dropdown = require "telescope.themes".get_dropdown()

  function enter(prompt_bufnr)
    actions.close(prompt_bufnr)
    local selected = actions_state.get_selected_entry()
    local fullpath = selected.value
    if cmd == 'tcd' then
      local win_list = vim.api.nvim_tabpage_list_wins(0)
      local bufname = vim.fn.bufname(vim.fn.bufnr())
      if #win_list > 1 or bufname ~= '' then
        cmd = 'tabnew | tcd'
      end
    end
    vim.cmd(cmd .. ' ' .. fullpath)
  end


  local opts = {
    finder = finders.new_table({
      results = resultList,
      entry_maker = function(item)

        --- @type project_picker_item
        local item = item

        local display_text = {}
        if item.category ~= "" then
          display_text[#display_text+1] = string.format("(%s)", item.category)
        end

        local util = require("tabs-as-projects.util")

        local path_parts = vim.split(item.absolute_path, "/")
        local last_n_parts = util.slice(
          path_parts,
          #path_parts - ((item.path_parts_to_display or 2) - 1),
          #path_parts
        )

        display_text[#display_text+1] = table.concat(last_n_parts, "/")

        return {
          display = table.concat(display_text, " "),
          value = item.absolute_path,
          ordinal = item.absolute_path,
        }
      end
    }),
    sorter = sorters.get_generic_fuzzy_sorter({}),

    attach_mappings = function(prompt_bufnr, map)
      map("n", "<CR>", enter)
      map("i", "<CR>", enter)
      return true
    end,

  }

  local dir_picker = pickers.new(dropdown, opts)

  dir_picker:find()
end

return M
