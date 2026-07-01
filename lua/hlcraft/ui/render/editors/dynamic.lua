local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local detail_render = require('hlcraft.ui.render.detail')

local M = {}

local function swatch_end_col(col_start, swatch)
  return col_start + vim.fn.strdisplaywidth(swatch)
end

local function append_editor_row(lines, geometry, key, text)
  local row = {
    line = #lines + 1,
    key = key,
  }
  geometry.editor_rows[key] = row
  lines[#lines + 1] = text
  return row
end

local function phase_label(phase)
  return phase == 1 and '1.00' or ('%.2f'):format(phase)
end

function M.build(instance, geometry, result, field, width, line_offset, dynamic)
  local label = ui_fields.detail_labels[field] or field:upper()
  local fallback = detail_render.fallback_value(result, field)
  local swatch = ui_fields.dynamic_preview_swatch
  local lines = {
    ('Color editor: %s'):format(label),
    string.rep('-', math.max(20, math.min(width, 36))),
    'Mode: dynamic',
    ('Preset: %s'):format(dynamic.preset or 'custom'),
    ('Duration: %dms'):format(dynamic.duration or 0),
  }

  append_editor_row(lines, geometry, 'dynamic_loop', ('Loop: %s'):format(dynamic.loop or 'repeat'))
  append_editor_row(lines, geometry, 'dynamic_phase', ('Phase: %.2f'):format(dynamic.phase or 0))

  lines[#lines + 1] = ('Swatch: %s'):format(swatch)

  dynamic_preview.register(instance, {
    line = 8 + line_offset,
    col_start = 8,
    col_end = swatch_end_col(8, swatch),
    text = swatch,
    field = field,
    base = fallback,
    dynamic = dynamic,
  })

  append_editor_row(lines, geometry, 'dynamic_raw_json', 'Raw JSON')

  local samples = { 0, 0.25, 0.5, 0.75, 1 }
  for _, phase in ipairs(samples) do
    local prefix = ('Sample %s: '):format(phase_label(phase))
    local row = append_editor_row(
      lines,
      geometry,
      ('dynamic_sample:%s'):format(phase_label(phase)),
      ('%s%s'):format(prefix, ui_fields.dynamic_timeline_swatch)
    )
    local sample_dynamic = vim.deepcopy(dynamic)
    sample_dynamic.phase = 0
    sample_dynamic.loop = 'once'
    local col_start = vim.fn.strdisplaywidth(prefix)
    dynamic_preview.register(instance, {
      line = row.line + line_offset,
      col_start = col_start,
      col_end = swatch_end_col(col_start, ui_fields.dynamic_timeline_swatch),
      text = ui_fields.dynamic_timeline_swatch,
      field = field,
      base = fallback,
      dynamic = sample_dynamic,
      now_ms = phase * math.max(1, tonumber(sample_dynamic.duration) or 1),
    })
  end

  append_editor_row(
    lines,
    geometry,
    'dynamic_keys',
    'Keys: i edit row, m preset, -/+ duration/phase, e raw JSON, d static, s save, q back'
  )

  for index, line in ipairs(lines) do
    if geometry.editor_rows.dynamic_keys and geometry.editor_rows.dynamic_keys.line == index then
      lines[index] = line
    else
      lines[index] = render_util.truncate(line, width)
    end
  end
  return lines
end

return M
