local render_util = require('hlcraft.render.util')
local group_editor = require('hlcraft.ui.editor.group')

local M = {}

local function append_editor_row(lines, geometry, key, text)
  local row = {
    line = #lines + 1,
    key = key,
  }
  geometry.editor_rows[key] = row
  lines[#lines + 1] = text
  return row
end

function M.build(geometry, result, width)
  local lines = {
    ('Group editor: %s'):format(result.name),
    string.rep('─', math.max(20, math.min(width, 36))),
  }
  for _, group_name in ipairs(group_editor.known_groups()) do
    append_editor_row(lines, geometry, 'group:' .. group_name, group_name)
  end
  append_editor_row(lines, geometry, 'new_group', '+ New group (i)')
  lines[#lines + 1] = 'Keys: Enter select, i input, s save, q back'
  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

return M
