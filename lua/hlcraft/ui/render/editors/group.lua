local render_util = require('hlcraft.render.util')
local group_editor = require('hlcraft.ui.editor.group')
local editor_rows = require('hlcraft.ui.render.editor_rows')
local hints = require('hlcraft.ui.render.hints')

local M = {}

function M.build(geometry, result, width)
  local lines = {
    ('Group editor: %s'):format(result.name),
    string.rep('─', math.max(20, math.min(width, 36))),
  }
  for _, group_name in ipairs(group_editor.known_groups()) do
    editor_rows.append(lines, geometry, 'group:' .. group_name, group_name)
  end
  editor_rows.append(lines, geometry, 'new_group', '+ New group (i)')
  lines[#lines + 1] = ''
  for _, line in ipairs(hints.group(width)) do
    lines[#lines + 1] = line
  end
  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

return M
