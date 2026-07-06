local handles = require('hlcraft.ui.handles')
local numbers = require('hlcraft.core.number')

local M = {}

local function assert_row0(row0)
  if type(row0) ~= 'number' then
    error('buffer row must be a number', 3)
  end
  if not numbers.is_integer(row0, 0) then
    error('buffer row must be a non-negative finite integer', 3)
  end
  return row0
end

function M.line(buf, row0, label)
  if not handles.is_valid_buf(buf) then
    error('buffer line lookup requires a valid buffer', 2)
  end
  row0 = assert_row0(row0)
  local line = vim.api.nvim_buf_get_lines(buf, row0, row0 + 1, false)[1]
  if type(line) ~= 'string' then
    error(('%s references missing buffer line %d'):format(label or 'buffer line lookup', row0 + 1), 2)
  end
  return line
end

return M
