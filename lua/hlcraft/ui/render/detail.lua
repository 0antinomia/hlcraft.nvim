local ui_fields = require('hlcraft.ui.fields')
local field_values = require('hlcraft.ui.field_values')
local render_util = require('hlcraft.render.util')
local session = require('hlcraft.ui.session')
local dynamic_model = require('hlcraft.dynamic.model')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local buffer = require('hlcraft.ui.render.buffer')
local decorations = require('hlcraft.ui.render.decorations')
local hints = require('hlcraft.ui.render.hints')
local detail_scene = require('hlcraft.ui.scene.detail')

local M = {}

local function dynamic_metadata(dynamic)
  local preset = dynamic.preset or 'custom'
  return ('%s %dms %s'):format(preset, dynamic.duration or 0, dynamic.loop or 'repeat')
end

local function swatch_end_col(col_start, swatch)
  return col_start + vim.fn.strdisplaywidth(swatch)
end

local function color_display_value(result, key)
  local dynamic = session.dynamic_value(result.name, key)
  if dynamic_model.channel_set[key] and dynamic then
    return ('████████ %s'):format(dynamic_metadata(dynamic))
  end
  local fallback = field_values.fallback_value(result, key)
  return session.display_value(result.name, key, fallback)
end

function M.build(instance, geometry, result, width, line_offset)
  assert(instance and instance.state, 'detail renderer requires an instance')
  assert(geometry and geometry.detail_menu, 'detail renderer requires detail geometry')
  assert(result and result.name, 'detail renderer requires a highlight result')
  line_offset = line_offset or 0
  local lines = {
    'Detail fields',
  }
  local label_width = 0
  for _, key in ipairs(ui_fields.detail_order) do
    label_width = math.max(label_width, vim.fn.strdisplaywidth(ui_fields.detail_labels[key] or key))
  end

  local dirty_mark = session.is_dirty(result.name) and '*' or ' '
  for _, key in ipairs(ui_fields.detail_order) do
    local fallback = field_values.fallback_value(result, key)
    local dynamic = dynamic_model.channel_set[key] and session.dynamic_value(result.name, key) or nil
    local value = key == 'group' and session.display_group(result.name)
      or ui_fields.detail_kinds[key] == 'color' and color_display_value(result, key)
      or session.display_value(result.name, key, fallback)
    local prefix = ('%s %s  '):format(dirty_mark, render_util.pad(ui_fields.detail_labels[key] or key, label_width))
    local value_col = #prefix
    local line = prefix .. field_values.display_text(value)
    local row = {
      line = #lines + 1,
      key = key,
      kind = ui_fields.detail_kinds[key],
    }
    geometry.detail_menu[key] = row
    if dynamic then
      local swatch = '████████'
      dynamic_preview.register(instance, {
        line = row.line + line_offset,
        col_start = value_col,
        col_end = swatch_end_col(value_col, swatch),
        text = swatch,
        field = key,
        base = fallback,
        dynamic = dynamic,
      })
    end
    lines[#lines + 1] = render_util.truncate(line, width)
  end

  lines[#lines + 1] = ''
  lines[#lines + 1] = hints.detail()

  return lines
end

function M.render(instance)
  local width = buffer.prepare(instance)
  if not width then
    return
  end

  local lines = {}
  local geometry = buffer.new_geometry()
  local results_top = buffer.append_search_inputs(instance, lines, geometry, width)
  local detail_result = detail_scene.current_result(instance)

  if detail_result then
    local detail_lines = M.build(instance, geometry, detail_result, width, results_top - 1)
    for _, line in ipairs(detail_lines) do
      lines[#lines + 1] = line
    end
    buffer.absolutize_detail_menu_geometry(geometry, results_top)
  end

  buffer.set_lines(instance, lines)
  buffer.finish(instance, geometry)
  decorations.apply_workbench_line_highlights(instance, lines, results_top)

  decorations.set_input_header(
    instance,
    geometry.name,
    ui_fields.search_prefixes.name,
    { top_virt_lines = { decorations.help_virt_line() } }
  )
  decorations.set_input_header(instance, geometry.color, ui_fields.search_prefixes.color)

  if detail_result then
    decorations.set_detail_menu_header(instance, results_top, detail_result)
    if session.is_dirty(detail_result.name) then
      decorations.apply_dirty_marks(instance, geometry.detail_menu)
    end
  end

  decorations.refresh_input_placeholders(instance)
  dynamic_preview.tick(instance, vim.uv.hrtime() / 1000000)
  dynamic_preview.sync(instance)
end

return M
