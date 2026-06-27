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

--- @class project_picker_item
--- @field absolute_path string
--- @field category string
--- @field project_name string
--- @field branch string

--- Builds the base picker item for a directory listed under `dir`.
--- @param dir search_dir_config
--- @param path string Absolute path of the discovered project directory
--- @return project_picker_item
local function build_base_item(dir, path)
  --- @type project_picker_item
  local item = {
    absolute_path = path,
    category = "",
    project_name = "",
    branch = "",
  }

  if dir.category ~= nil and dir.category ~= "" then
    item.category = dir.category
  end

  local util = require("tabs-as-projects.util")
  local path_parts = vim.split(path, "/")
  local last_n_parts = util.slice(
    path_parts,
    #path_parts - ((dir.display_path_parts or 2) - 1),
    #path_parts
  )
  item.project_name = table.concat(last_n_parts, "/")

  return item
end

local build_entry_maker = function(category_width, project_name_width)

  local entry_display = require("telescope.pickers.entry_display")

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = category_width, right_justify = true },
      { width = project_name_width },
      {},
    }
  })

  local entry_maker = function(item)

    --- @type project_picker_item
    local item = item

    return {
      display = function (_)
        return displayer({
          { item.category, "TabProjects_Picker_Category"},
          { item.project_name, "TabProjects_Picker_Entry"},
          { item.branch, "TabProjects_Picker_Branch"},
        })
      end,
      value = item.absolute_path,
      ordinal = item.project_name .. " " .. item.branch,
    }
  end

  return entry_maker
end

--- @param opts pick_project_options
function M.pick_project(opts)

  local dirs = opts.search_dirs

  local list_dir = require("tabs-as-projects.list_dir_fn").find_list_dir
  if opts.list_dir ~= nil then
    list_dir = opts.list_dir
  end

  local actions = require "telescope.actions"
  local pickers = require "telescope.pickers"
  local sorters = require "telescope.sorters"

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

  --- @type table<string, project_picker_item>
  local result_list = {}

  local display_opts = {
    category_width = 0,
    project_name_width = 0
  }

  local gen_finder = function()

    local list = {}
    for _, item in pairs(result_list) do
      list[#list+1] = item
    end

    return require("telescope.finders").new_table({
        results = list,
        entry_maker = build_entry_maker(
          display_opts.category_width,
          display_opts.project_name_width
        ),
      })
  end

  local dir_picker = pickers.new(
    require "telescope.themes".get_dropdown(),
    {
      prompt_title = "Pick project",
      finder = gen_finder(),
      sorter = sorters.get_generic_fuzzy_sorter({}),
      attach_mappings = attach_mappings_fn,
    }
  )

  dir_picker:find()

  local git_worktrees = require("tabs-as-projects.git_worktrees")

  --- @class fetch_worktree_queue_item
  --- @field item_index number
  --- @field base_item project_picker_item
  ---
  --- @type project_picker_item[]
  local fetch_worktree_queue = {}

  for _, dir in ipairs(dirs) do
    local absolute_dir_path = vim.fn.expand(dir.path)
    for _, path in ipairs(list_dir(absolute_dir_path)) do
      if path == absolute_dir_path then
        goto continue
      end

      local item = build_base_item(dir, path)

      display_opts.category_width = math.max(display_opts.category_width, #dir.category)
      display_opts.project_name_width = math.max(display_opts.project_name_width, #item.project_name)

      result_list[item.absolute_path] = item
      dir_picker:refresh(gen_finder())

      fetch_worktree_queue[#fetch_worktree_queue+1] = item

      ::continue::
    end
  end

  local function process_in_batches(items, batch_size, callback)
    local i = 1

    local function process_next_batch()
      local batch = {}
      for j = 1, batch_size do
        if i > #items then break end
        batch[j] = items[i]
        i = i + 1
      end

      if #batch > 0 then
        callback(batch, function()
          if i <= #items then
            vim.schedule(process_next_batch) -- yield to event loop
          end
        end)
      end
    end

    process_next_batch()
  end

  process_in_batches(fetch_worktree_queue, 10, function (batch, done)
    for _, queue_item in ipairs(batch) do

      git_worktrees.list(queue_item.absolute_path, function (worktrees)

        for i, worktree in ipairs(worktrees) do

          --- @type project_picker_item
          local wt_item = {
            category      = queue_item.category,
            project_name  = queue_item.project_name,
            absolute_path = worktree.absolute_path,
            branch        = worktree.branch,
          }

          result_list[worktree.absolute_path] = wt_item

          dir_picker:refresh(gen_finder())

        end

        if queue_item.absolute_path == batch[#batch].absolute_path then
          done()
        end

      end)
    end
  end)

end


return M
