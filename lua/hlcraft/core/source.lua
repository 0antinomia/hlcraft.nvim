--- @type table
local M = {}

--- Get the definition source for a highlight group
--- @param group_name string Highlight group name
--- @return string|nil file_path Path to the file that defined the group
--- @return number|nil line_number Line number within that file
function M.get_source(group_name)
  local ok, output = pcall(vim.fn.execute, 'verbose highlight ' .. group_name)
  if not ok or not output or output == '' then
    return nil, nil
  end

  local path = output:match('Last set from (.+) line %d+') or output:match('Last set from (.+)')
  if not path then
    return nil, nil
  end

  path = vim.trim(path)
  local line_num = tonumber(output:match('Last set from .+ line (%d+)'))

  return path, line_num
end

return M
