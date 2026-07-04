local field_values = require('hlcraft.ui.field_values')
local render_util = require('hlcraft.render.util')
local session = require('hlcraft.ui.session')
local hints = require('hlcraft.ui.render.hints')

local M = {}

function M.build(geometry, result, width)
  local fallback = field_values.fallback_value(result, 'blend')
  local value = session.display_value(result.name, 'blend', fallback)
  local lines = {
    'Blend editor',
    string.rep('─', math.max(20, math.min(width, 36))),
    ('Current: %s'):format(field_values.display_text(value)),
  }
  lines[#lines + 1] = ''
  for _, line in ipairs(hints.blend(width)) do
    lines[#lines + 1] = line
  end

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

return M
