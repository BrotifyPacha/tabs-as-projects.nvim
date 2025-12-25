local M = {}

M.check = function()
  vim.health.start("Checking for required plugins")

  local ok = require 'telescope'
  if ok then
    vim.health.ok("telescope installed.")
  end

  vim.health.start("Checking for required binaries")

  local binaries = {
    "find",
  }

  for _, binary in ipairs(binaries) do
    local status = vim.fn.executable(binary)
    if status == 1 then
      vim.health.ok("'" .. binary .. "' binary is available")
    else
      vim.health.warn("'" .. binary .. "' binary is not available")
    end
  end

end

return M
