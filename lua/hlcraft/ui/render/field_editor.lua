local dynamic_model = require('hlcraft.dynamic.model')
local session = require('hlcraft.ui.session')
local ui_fields = require('hlcraft.ui.fields')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local buffer = require('hlcraft.ui.render.buffer')
local decorations = require('hlcraft.ui.render.decorations')
local color_renderer = require('hlcraft.ui.render.editors.color')
local dynamic_renderer = require('hlcraft.ui.render.editors.dynamic')
local group_renderer = require('hlcraft.ui.render.editors.group')
local blend_renderer = require('hlcraft.ui.render.editors.blend')
local detail_scene = require('hlcraft.ui.scene.detail')
local theme = require('hlcraft.ui.theme')

local M = {}

local function normalize_build_args(instance, geometry, result, field, width, line_offset)
  if line_offset ~= nil or width ~= nil then
    return instance, geometry, result, field, width, line_offset or 0
  end

  return nil, instance, geometry, result, field, 0
end

function M.build(instance, geometry, result, field, width, line_offset)
  instance, geometry, result, field, width, line_offset =
    normalize_build_args(instance, geometry, result, field, width, line_offset)
  if field == 'fg' or field == 'bg' or field == 'sp' then
    local dynamic = dynamic_model.channel_set[field] and session.dynamic_value(result.name, field) or nil
    if dynamic then
      return dynamic_renderer.build(instance, geometry, result, field, width, line_offset, dynamic)
    end
    return color_renderer.build(instance, geometry, result, field, width, line_offset)
  end
  if field == 'group' then
    return group_renderer.build(geometry, result, width)
  end
  if field == 'blend' then
    return blend_renderer.build(geometry, result, width)
  end
  return nil
end

local function apply_color_marker(instance, lines, geometry, key)
  if not geometry[key] then
    return
  end
  local line = lines[geometry[key].line] or ''
  local start_col = decorations.find_text_start(line, geometry[key].text, 0)
  decorations.apply_color_cell(
    instance,
    instance.state.buf,
    geometry[key].line - 1,
    start_col or 0,
    geometry[key].text,
    geometry[key].value,
    geometry[key].field
  )
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
  local field = instance.state.field_editor and instance.state.field_editor.field or nil

  if detail_result and field then
    local editor_lines = M.build(instance, geometry, detail_result, field, width, results_top - 1)
    if editor_lines then
      for _, line in ipairs(editor_lines) do
        lines[#lines + 1] = line
      end
      buffer.absolutize_detail_menu_geometry(geometry, results_top)
      buffer.absolutize_editor_geometry(geometry, results_top)
    end
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
    local detail_virt_lines = select(1, decorations.detail_info_virt_lines(instance, detail_result))
    instance.state.input_marks.detail_menu_header =
      vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, results_top - 1, 0, {
        id = instance.state.input_marks.detail_menu_header,
        virt_lines = detail_virt_lines,
        virt_lines_leftcol = true,
        virt_lines_above = true,
        right_gravity = false,
      })

    apply_color_marker(instance, lines, geometry, 'color_sample')
    apply_color_marker(instance, lines, geometry, 'color_swatch')

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
