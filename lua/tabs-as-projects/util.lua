local M = {}

--- @param list any[]
--- @param first integer
--- @param last integer
--- @return any[]
function M.slice(list, first, last)
  local sliced = {}

  for i = first, last, 1 do
    sliced[#sliced+1] = list[i]
  end

  return sliced
end

return M
