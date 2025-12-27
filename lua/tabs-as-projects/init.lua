require 'tabs-as-projects.health'

local M = {
  pick_project = function(opts)
    return function()
      require("tabs-as-projects.picker").pick_project(opts)
    end
  end
}

return M
