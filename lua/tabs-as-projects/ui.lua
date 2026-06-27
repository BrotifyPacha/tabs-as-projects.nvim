local M = {
  --- @type ui_options
  opts = {
    tab_label_format = '(%s)'
  }
}

--- @param name string
--- @return vim.api.keyset.highlight
local function get_hl(name)
  return vim.api.nvim_get_hl(0, { name = name , link = false})
end

--- @param name string
--- @param opts vim.api.keyset.highlight 
--- @return vim.api.keyset.highlight
local function create_hl(name, opts)
  if opts.link ~= nil then
    opts = get_hl(opts.link)
  end
  opts.force = true
  vim.api.nvim_set_hl(0, name, opts)
  return opts
end

--- @param name string
--- @param opts vim.api.keyset.highlight 
--- @return vim.api.keyset.highlight
local function extend_hl(name, opts)
  return vim.tbl_extend("force", get_hl(name), opts)
end

local function setup_colors()
  local added_hl = get_hl("Added")

  local tab_hl = create_hl("TabProjects_Tab", { link = "Tabline"})
  local sel_hl = create_hl("TabProjects_TabSelected", { link="Normal" })
  create_hl("TabProjects_TabSelectedBold", extend_hl("TabProjects_TabSelected", { bold = true }))
  create_hl("TabProjects_Divider", extend_hl("TabProjects_Tab", { fg = sel_hl.bg }))
  create_hl("TabProjects_DividerSelected", { fg = sel_hl.bg, bg = tab_hl.bg })

  create_hl("TabProjects_Tab_Branch", extend_hl('TabProjects_Tab', { fg = added_hl.fg, dim = true }))
  create_hl("TabProjects_TabSelected_Branch", extend_hl('TabProjects_TabSelected', { fg = added_hl.fg }) )

  create_hl("TabProjects_Picker_Category", { link = "Comment" })
  create_hl("TabProjects_Picker_Entry", { link = "Normal" })
  create_hl("TabProjects_Picker_Branch", { link = "Added" })
end

setup_colors()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function () setup_colors() end
})

--- @class ui_options
--- @field close_icon string|nil
--- @field branch_icon string|nil
--- @field use_nerd_font boolean|nil
--- @field tab_label_format string|nil

--- @param opts ui_options
function M.setup(opts)

  if opts.use_nerd_font then
    M.opts.close_icon = ''
    M.opts.branch_icon = ''
  end

  M.opts.tab_label_format = M.opts.branch_icon .. ' %s'

  if opts.close_icon ~= nil then
    M.opts.close_icon = opts.close_icon
  end

  if opts.tab_label_format ~= nil then
    M.opts.tab_label_format = opts.tab_label_format
  end

end

function M.tabline()
  local tabs = {}
  local selected_tab = vim.fn.tabpagenr()
  for tab_index, tab_id in ipairs(vim.api.nvim_list_tabpages()) do

    local is_selected = tab_index == selected_tab

    local tab_label = M.tab_label(is_selected, tab_index, tab_id)
    local tab_selector = '%' .. tab_index .. 'T'
    local tab_closer = ''
    if M.opts.close_icon ~= nil and #(M.opts.close_icon) > 0 then
      tab_closer = '%' .. tab_index  .. 'X'.. M.opts.close_icon .. ' '
    end
    local tab_button = tab_selector .. tab_label .. ' ' .. tab_closer .. '%T'

    local sep_highlight = '%#TabProjects_Divider#'
    local sep = '│'
    if tab_index + 1 == vim.fn.tabpagenr() then
      sep_highlight = '%#TabProjects_DividerSelected#'
      sep = '▐'
    else if tab_index == vim.fn.tabpagenr() and tab_index ~= vim.fn.tabpagenr('$') then
      sep_highlight = '%#TabProjects_DividerSelected#'
      sep = '▌'
    else if tab_index == vim.fn.tabpagenr('$') then
      sep = ''
    end
      end
    end

    tabs[#tabs+1] = tab_button .. sep_highlight .. sep
  end

  local tab_line = table.concat(tabs, "" )

  return tab_line
end

function M.tab_label(tab_selected, tab_number, tab_id)

  local git_worktrees = require("tabs-as-projects.git_worktrees")

  local cwds = M.get_unique_cwds_on_tab(tab_number, tab_id)

  local selected_cwd = vim.fn.getcwd(0, tab_number)
  for i, cwd in ipairs(cwds) do
    local tab_highlight, tab_branch_highlight = M.get_tab_highlights(tab_selected, cwd == selected_cwd)

    local project_root
    local root_results = vim.fs.find({ ".git" }, { upward = true, limit = 10, type = "directory", path = cwd })
    if #root_results ~= 0 then
      project_root = vim.fs.dirname(root_results[1])
    end

    local tab_branch = ""
    for _, worktree in ipairs(git_worktrees.list_sync(cwd)) do
      if worktree.absolute_path == cwd then
        tab_branch = worktree.branch
      end
    end

    local tab_dir = cwd
    if project_root ~= nil then
      tab_dir = project_root
    end

    local dir_name = vim.fn.substitute(tab_dir, '.*[/\\\\]', '', '')

    local tab_label = dir_name
    if tab_branch ~= "" then
      tab_label = dir_name .. ' ' .. tab_branch_highlight .. string.format(M.opts.tab_label_format, tab_branch) .. tab_highlight
    end

    cwds[i] = tab_highlight .. " " .. tab_label
  end
  return table.concat(vim.tbl_flatten(cwds), " /")
end

--- @return string tab_highlight
--- @return string tab_branch_highlight
function M.get_tab_highlights(tab_selected, dir_is_current_dir)
  if not tab_selected then
    return '%#TabProjects_Tab#', '%#TabProjects_Tab_Branch#'
  end

  if dir_is_current_dir then
    return '%#TabProjects_TabSelectedBold#', '%#TabProjects_TabSelected_Branch#'
  end

  return '%#TabProjects_TabSelected#', '%#TabProjects_TabSelected_Branch#'
end

function M.get_unique_cwds_on_tab(tab_number, tab_id)
  local cwds = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab_id)) do
    local cwd = vim.fn.getcwd(win, tab_number)
    if not vim.tbl_contains(cwds, cwd) then
      cwds[#cwds+1] = cwd
    end
  end
  return cwds
end

return M
