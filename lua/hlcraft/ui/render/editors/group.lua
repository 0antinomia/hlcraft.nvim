local group_editor = require('hlcraft.ui.editor.group')
local editor_layout = require('hlcraft.ui.render.editor_layout')
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
  return editor_layout.finish(lines, width, hints.group(width))
end

return M
