local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local session = require('hlcraft.ui.session')
local dynamic_model = require('hlcraft.dynamic.model')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local buffer = require('hlcraft.ui.render.buffer')
local decorations = require('hlcraft.ui.render.decorations')
local detail_scene = require('hlcraft.ui.scene.detail')
local theme = require('hlcraft.ui.theme')

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
  local fallback = M.fallback_value(result, key)
  return session.display_value(result.name, key, fallback)
end

local function normalize_build_args(instance, geometry, result, width, line_offset)
  if line_offset ~= nil or width ~= nil then
    return instance, geometry, result, width, line_offset or 0
  end

  return nil, instance, geometry, result, 0
end

function M.build(instance, geometry, result, width, line_offset)
  instance, geometry, result, width, line_offset = normalize_build_args(instance, geometry, result, width, line_offset)
  local lines = {
    'Detail fields  (<CR> edit/toggle, s save, q back)',
  }
  local label_width = 0
  for _, key in ipairs(ui_fields.detail_order) do
    label_width = math.max(label_width, vim.fn.strdisplaywidth(ui_fields.detail_labels[key] or key))
  end

  local dirty_mark = session.is_dirty(result.name) and '*' or ' '
  for _, key in ipairs(ui_fields.detail_order) do
    local fallback = M.fallback_value(result, key)
    local dynamic = dynamic_model.channel_set[key] and session.dynamic_value(result.name, key) or nil
    local value = key == 'group' and session.display_group(result.name)
      or ui_fields.detail_kinds[key] == 'color' and color_display_value(result, key)
      or session.display_value(result.name, key, fallback)
    local prefix = ('%s %s  '):format(dirty_mark, render_util.pad(ui_fields.detail_labels[key] or key, label_width))
    local value_col = #prefix
    local line = prefix .. M.display_text(value)
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

  lines[#lines + 1] = 'Keys: Enter edit/toggle, s save, q back, ? help'

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

  decorations.set_input_header(
    instance,
    geometry.name,
    ui_fields.search_prefixes.name,
    { top_virt_lines = { decorations.help_virt_line() } }
  )
  decorations.set_input_header(instance, geometry.color, ui_fields.search_prefixes.color)

  if detail_result then
    local detail_virt_lines = select(1, decorations.detail_info_virt_lines(instance, detail_result))
    instance.state.input_marks.detail_menu_header =
      vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, results_top - 1, 0, {
        id = instance.state.input_marks.detail_menu_header,
        virt_lines = detail_virt_lines,
        virt_lines_leftcol = true,
        virt_lines_above = true,
        right_gravity = false,
      })

    if session.is_dirty(detail_result.name) then
      for _, row in pairs(geometry.detail_menu or {}) do
        vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.dirty, row.line - 1, 0, 1)
      end
    end
  end

  decorations.refresh_input_placeholders(instance)
  dynamic_preview.tick(instance, vim.uv.hrtime() / 1000000)
  dynamic_preview.sync(instance)
end

return M
