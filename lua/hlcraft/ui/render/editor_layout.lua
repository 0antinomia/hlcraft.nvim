local numbers = require('hlcraft.core.number')
local render_util = require('hlcraft.render.util')

local M = {}

local function string_list(lines, label)
  return render_util.string_list(lines, label, 3)
end

local function render_width(width)
  return numbers.assert_non_negative_integer(width, 'editor layout width', 3)
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
