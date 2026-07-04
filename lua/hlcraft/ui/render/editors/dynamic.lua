local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local editor_rows = require('hlcraft.ui.render.editor_rows')
local hints = require('hlcraft.ui.render.hints')
local detail_render = require('hlcraft.ui.render.detail')

local M = {}

local function swatch_end_col(col_start, swatch)
  return col_start + vim.fn.strdisplaywidth(swatch)
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
    string.rep('─', math.max(20, math.min(width, 36))),
    'Mode: dynamic',
    ('Preset: %s'):format(dynamic.preset or 'custom'),
    ('Duration: %dms'):format(dynamic.duration or 0),
  }

  editor_rows.append(lines, geometry, 'dynamic_loop', ('Loop: %s'):format(dynamic.loop or 'repeat'))
  editor_rows.append(lines, geometry, 'dynamic_phase', ('Phase: %.2f'):format(dynamic.phase or 0))

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

  editor_rows.append(lines, geometry, 'dynamic_raw_json', 'Raw JSON')

  local samples = { 0, 0.25, 0.5, 0.75, 1 }
  for _, phase in ipairs(samples) do
    local prefix = ('Sample %s: '):format(phase_label(phase))
    local row = editor_rows.append(
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

  lines[#lines + 1] = ''
  for _, line in ipairs(hints.dynamic()) do
    lines[#lines + 1] = line
  end

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

return M
