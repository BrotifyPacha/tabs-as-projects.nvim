local M = {}

--- @alias list_dir_fn fun(path: string): string[]

--- Constructs a 'list_dir_fn' using provided command
--- @return fun(cmd: string): list_dir_fn
function M.list_using_cmd(cmd)
  return function (path)
    assert(path ~= "", "path cannot be empty")

    local absolute_path = vim.fn.expand(path)

    --- @type string[]
    local out = {}

    local find_results = io.popen(string.format(cmd, absolute_path))
    assert(find_results ~= nil, "error executing command: " .. cmd)

    for item in find_results:lines() do

      out[#out+1] = item

    end
    find_results:close()

    return out
  end
end

--- Lists directories using 'find' command
--- @type list_dir_fn
M.find_list_dir = M.list_using_cmd('find "%s" -maxdepth 1 -type d')

return M
