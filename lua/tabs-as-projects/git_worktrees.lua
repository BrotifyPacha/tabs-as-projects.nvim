local M = {}

--- @class git_worktree
--- @field absolute_path string Absolute path to the worktree directory
--- @field project_relative_path string Worktree path relative to the repository root
--- @field dir_name string Last path component of the worktree directory
--- @field branch string Checked out branch (without the "refs/heads/" prefix, "" when detached)

--- Parses the output of `git worktree list --porcelain`.
---
--- Each worktree is described by a block of `key value` lines separated from the
--- next block by a blank line, e.g.:
---
---   worktree /path/to/main
---   HEAD 5fa38f4a988a8accd7fad60370b2c7c42b2980fe
---   branch refs/heads/main
---
--- @param output string Raw porcelain output
--- @return table[] worktrees Raw records with `absolute_path`, `dir_name`, `branch`, `head` and `bare` fields
local function parsePorcelainGitWorktreeOutput(output)
  --- @type table[]
  local worktrees = {}
  local current = nil

  local function flush()
    if current ~= nil then
      worktrees[#worktrees+1] = current
      current = nil
    end
  end

  -- Iterate line by line; a blank line terminates the current worktree block.
  for line in (output .. "\n"):gmatch("([^\n]*)\n") do
    if line == "" then
      flush()
    else
      local key, value = line:match("^(%S+)%s*(.*)$")
      if key == "worktree" then
        current = { absolute_path = value, dir_name = value:match("[^/]+$") or value }
      elseif current ~= nil then
        if key == "HEAD" then
          current.head = value
        elseif key == "branch" then
          current.branch = (value:gsub("^refs/heads/", ""))
        elseif key == "bare" then
          current.bare = true
        elseif key == "detached" then
          current.detached = true
        end
      end
    end
  end

  -- Safety net in case the output is not terminated by a blank line.
  flush()

  return worktrees
end

--- Returns `absolute_path` expressed relative to `base`, or the unchanged
--- `absolute_path` when it does not live under `base`.
--- @param absolute_path string
--- @param base string
--- @return string
local function path_relative_to(absolute_path, base)
  base = base:gsub("/+$", "")
  if absolute_path == base then
    return ""
  end
  if absolute_path:sub(1, #base + 1) == base .. "/" then
    return absolute_path:sub(#base + 2)
  end
  return absolute_path
end

--- Turns raw porcelain records into the public `git_worktree[]` shape, dropping
--- the bare entry of a bare repository (it is not a checkout one can switch to).
--- @param raw table[] Records produced by `parsePorcelainGitWorktreeOutput`
--- @param fallback_root string Used when `git` produced no worktree entry
--- @return git_worktree[]
local function build_worktrees(raw, fallback_root)
  -- The first entry reported by git is the main (or bare) worktree; treat its
  -- location as the repository root so relative paths are stable regardless of
  -- which worktree `path` happened to point at.
  local root = raw[1] and raw[1].absolute_path or fallback_root

  --- @type git_worktree[]
  local result = {}
  for _, wt in ipairs(raw) do
    if not wt.bare then
      result[#result+1] = {
        absolute_path = wt.absolute_path,
        project_relative_path = path_relative_to(wt.absolute_path, root),
        dir_name = wt.dir_name,
        branch = wt.branch or "",
      }
    end
  end

  return result
end

--- Lists the git worktrees of the repository that `path` belongs to.
--- Returns an empty list when `path` is not part of a git repository.
---
--- The bare entry of a bare repository is omitted as it is not a checkout one
--- can switch to.
---
--- @param path string Path inside (or at the root of) a git repository
--- @param on_done fun(worktrees: git_worktree[]) callback function
function M.list(path, on_done)
  assert(path ~= nil and path ~= "", "path cannot be empty")

  local absolute_path = vim.fn.expand(path)

  vim.system(
    { "git", "-C", absolute_path, "worktree", "list", "--porcelain" },
    { text = true },
    function (obj)
      local raw = parsePorcelainGitWorktreeOutput(obj.stdout)
      on_done(build_worktrees(raw, absolute_path))
    end
  )

end

--- Lists the git worktrees of the repository that `path` belongs to.
--- Returns an empty list when `path` is not part of a git repository.
---
--- The bare entry of a bare repository is omitted as it is not a checkout one
--- can switch to.
---
--- @param path string Path inside (or at the root of) a git repository
--- @return git_worktree[]
function M.list_sync(path)
  assert(path ~= nil and path ~= "", "path cannot be empty")

  local absolute_path = vim.fn.expand(path)

  local obj = vim.system(
    { "git", "-C", absolute_path, "worktree", "list", "--porcelain" },
    { text = true }
  ):wait()

  local raw = parsePorcelainGitWorktreeOutput(obj.stdout)

  return build_worktrees(raw, absolute_path)

end



return M
