local render_util = require('hlcraft.render.util')
local session = require('hlcraft.ui.session')
local detail_render = require('hlcraft.ui.render.detail')

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
  local fallback = detail_render.fallback_value(result, 'blend')
  local value = session.display_value(result.name, 'blend', fallback)
  local lines = {
    'Blend editor',
    string.rep('─', math.max(20, math.min(width, 36))),
    ('Current: %s'):format(detail_render.display_text(value)),
  }
  append_editor_row(lines, geometry, 'blend_keys', 'Keys: -/+ small, </> large, u unset, i input, s save, q back')

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

return M
