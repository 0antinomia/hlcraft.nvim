local numbers = require('hlcraft.core.number')
local render_util = require('hlcraft.render.util')

local M = {}

local function string_list(lines, label)
  return render_util.string_list(lines, label, 3)
end

local function render_width(width)
  if type(width) ~= 'number' then
    error('editor layout width must be a number', 3)
  end
  if not numbers.is_finite(width) or math.floor(width) ~= width or width < 0 then
    error('editor layout width must be a non-negative finite integer', 3)
  end
  return width
end

function M.append_hint_block(lines, hint_lines)
  lines = string_list(lines, 'editor layout lines')
  hint_lines = string_list(hint_lines, 'editor layout hint lines')
  lines[#lines + 1] = ''
  for _, line in ipairs(hint_lines) do
    lines[#lines + 1] = line
  end
end

function M.truncate(lines, width)
  lines = string_list(lines, 'editor layout lines')
  width = render_width(width)
  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

function M.finish(lines, width, hint_lines)
  string_list(lines, 'editor layout lines')
  render_width(width)
  string_list(hint_lines, 'editor layout hint lines')
  M.append_hint_block(lines, hint_lines)
  return M.truncate(lines, width)
end

return M
