local M = {}

local function get_hl(name)
  return vim.api.nvim_get_hl(0, { name = name , link = false})
end

local function create_hl(name, opts)
  if opts.link ~= nil then
    opts = get_hl(opts.link)
  end
  opts.force = true
  vim.api.nvim_set_hl(0, name, opts)
  return opts
end

local function extend_hl(name, opts)
  return vim.tbl_extend("force", get_hl(name), opts)
end

local function setup_colors()
  local tab_hl = create_hl("TabProjects_Tab", { link = "Tabline"})
  local sel_hl = create_hl("TabProjects_TabSelected", { link="Normal" })
  create_hl("TabProjects_TabSelectedBold", extend_hl("TabProjects_TabSelected", { bold = true }))
  create_hl("TabProjects_Divider", extend_hl("TabProjects_Tab", { fg = sel_hl.bg }))
  create_hl("TabProjects_DividerSelected", { fg = sel_hl.bg, bg = tab_hl.bg })
end

setup_colors()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function () setup_colors() end
})

function M.tabline()
  local tabs = {}
  local selected_tab = vim.fn.tabpagenr()
  for tab_index, tab_id in ipairs(vim.api.nvim_list_tabpages()) do

    local is_selected = tab_index == selected_tab

    local tab_label = M.tab_label(is_selected, tab_index, tab_id)
    local tab_selector = '%' .. tab_index .. 'T'
    local tab_closer = '%' .. tab_index  .. 'X%T '
    local tab_button = tab_selector .. tab_label .. ' ' .. tab_closer

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

  local cwds = M.get_unique_cwds_on_tab(tab_number, tab_id)

  local selected_cwd = vim.fn.getcwd(0, tab_number)
  for i, cwd in ipairs(cwds) do
    local tab_highlight = M.get_tab_highlight(tab_selected, cwd == selected_cwd)
    cwd = vim.fn.substitute(cwd, '.*[/\\\\]', '', '')
    cwds[i] = tab_highlight .. " " .. cwd
  end
  return table.concat(vim.tbl_flatten(cwds), " /")
end

function M.get_tab_highlight(tab_selected, dir_is_current_dir)
  if not tab_selected then
    return '%#TabProjects_Tab#'
  end

  if dir_is_current_dir then
    return '%#TabProjects_TabSelectedBold#'
  end

  return '%#TabProjects_TabSelected#'
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
