require 'tabs-as-projects.health'

local M = {
  opts = {},
}

--- @class setup_options
--- @field ui any

--- @param opts setup_options
function M.setup(opts)

  M.opts = opts

  if opts.ui ~= nil then
    require("tabs-as-projects.ui").setup(opts.ui)
  end

end

function M.pick_project(opts)
  return function()
    require("tabs-as-projects.picker").pick_project(opts)
  end
end

return M
