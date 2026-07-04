local render_util = require('hlcraft.render.util')

local M = {}

function M.append_hint_block(lines, hint_lines)
  lines[#lines + 1] = ''
  for _, line in ipairs(hint_lines) do
    lines[#lines + 1] = line
  end
end

function M.truncate(lines, width)
  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

function M.finish(lines, width, hint_lines)
  M.append_hint_block(lines, hint_lines)
  return M.truncate(lines, width)
end

return M
