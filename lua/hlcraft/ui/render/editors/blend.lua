local render_util = require('hlcraft.render.util')
local session = require('hlcraft.ui.session')
local hints = require('hlcraft.ui.render.hints')
local detail_render = require('hlcraft.ui.render.detail')

local M = {}

function M.build(geometry, result, width)
  local fallback = detail_render.fallback_value(result, 'blend')
  local value = session.display_value(result.name, 'blend', fallback)
  local lines = {
    'Blend editor',
    string.rep('─', math.max(20, math.min(width, 36))),
    ('Current: %s'):format(detail_render.display_text(value)),
  }
  lines[#lines + 1] = hints.blend_adjust()
  lines[#lines + 1] = hints.blend_global()

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

return M
