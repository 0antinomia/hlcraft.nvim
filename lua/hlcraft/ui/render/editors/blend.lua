local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local session = require('hlcraft.ui.session')
local detail_menu = require('hlcraft.ui.render.detail_menu')

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
  local fallback = detail_menu.fallback_value(result, 'blend')
  local value = session.display_value(result.name, 'blend', fallback)
  local lines = {
    'Blend editor',
    string.rep('─', math.max(20, math.min(width, 36))),
    ('Current: %s'):format(detail_menu.display_text(value)),
  }
  append_editor_row(
    lines,
    geometry,
    'blend_keys',
    ('Keys: -/+ by %d, </> by %d, u unset, i input, s save, q back'):format(
      ui_fields.blend_small_step,
      ui_fields.blend_large_step
    )
  )

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

return M
