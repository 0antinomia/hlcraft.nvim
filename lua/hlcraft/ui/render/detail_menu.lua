local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local detail_values = require('hlcraft.ui.state.detail_values')
local dynamic_model = require('hlcraft.dynamic.model')

local M = {}

function M.fallback_value(result, key)
  if key == 'fg' then
    return result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  end
  if key == 'bg' then
    return result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  end
  if key == 'sp' then
    return result.sp
  end
  return result[key]
end

function M.display_text(value)
  if value == nil then
    return 'unset'
  end
  if value == true then
    return 'true'
  end
  if value == false then
    return 'false'
  end
  return tostring(value)
end

local function color_display_value(result, key)
  local dynamic = detail_values.dynamic_value(result.name, key)
  if dynamic_model.channel_set[key] and dynamic then
    return ('dynamic:%s %dms'):format(dynamic.mode, dynamic.speed)
  end
  local fallback = M.fallback_value(result, key)
  return detail_values.display_value(result.name, key, fallback)
end

function M.build(geometry, result, width)
  local lines = {
    'Detail fields  (<CR> edit/toggle, s save, q back)',
  }
  local label_width = 0
  for _, key in ipairs(ui_fields.detail_order) do
    label_width = math.max(label_width, vim.fn.strdisplaywidth(ui_fields.detail_labels[key] or key))
  end

  local dirty_mark = detail_values.is_dirty(result.name) and '*' or ' '
  for _, key in ipairs(ui_fields.detail_order) do
    local fallback = M.fallback_value(result, key)
    local value = key == 'group' and detail_values.display_group(result.name)
      or ui_fields.detail_kinds[key] == 'color' and color_display_value(result, key)
      or detail_values.display_value(result.name, key, fallback)
    local line = ('%s %s  %s'):format(
      dirty_mark,
      render_util.pad(ui_fields.detail_labels[key] or key, label_width),
      M.display_text(value)
    )
    geometry.detail_menu[key] = {
      line = #lines + 1,
      key = key,
      kind = ui_fields.detail_kinds[key],
    }
    lines[#lines + 1] = render_util.truncate(line, width)
  end

  return lines
end

return M
