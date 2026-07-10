local dynamic_model = require('hlcraft.dynamic.model')
local render_util = require('hlcraft.render.util')
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

local M = {}

local function render_instance(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('field editor renderer requires an instance', 3)
  end
  return instance
end

local function render_state(instance)
  return render_instance(instance).state
end

local function field_editor_state(state)
  if type(state.field_editor) ~= 'table' then
    error('field editor renderer state must be a table', 3)
  end
  return state.field_editor
end

local function editor_geometry(geometry)
  if type(geometry) ~= 'table' or type(geometry.editor_rows) ~= 'table' then
    error('field editor renderer requires editor geometry', 3)
  end
  return geometry
end

local function highlight_result(result)
  if type(result) ~= 'table' or type(result.name) ~= 'string' or result.name == '' then
    error('field editor renderer requires a highlight result', 3)
  end
  return result
end

local function current_field(state)
  local field = field_editor_state(state).field
  if field ~= nil and (type(field) ~= 'string' or field == '') then
    error('field editor renderer field must be a non-empty string or nil', 3)
  end
  return field
end

local function marker_geometry(geometry, key)
  local marker = geometry[key]
  if marker == nil then
    return nil
  end
  if type(marker) ~= 'table' then
    error(('%s marker geometry must be a table'):format(key), 3)
  end
  return marker
end

function M.build(instance, geometry, result, field, width, line_offset)
  instance = render_instance(instance)
  geometry = editor_geometry(geometry)
  result = highlight_result(result)
  if type(field) ~= 'string' or field == '' then
    error('field editor renderer requires a field', 2)
  end
  line_offset = render_util.line_offset(line_offset, 'field editor renderer')

  if dynamic_model.channel_set[field] then
    local dynamic = session.dynamic_value(result.name, field)
    if dynamic then
      return dynamic_renderer.build(instance, geometry, result, field, width, line_offset, dynamic)
    end
    return color_renderer.build(geometry, result, field, width)
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
  local state = render_state(instance)
  local marker = marker_geometry(geometry, key)
  if not marker then
    return
  end
  local line = render_util.line_at(lines, marker.line, ('%s marker geometry'):format(key))
  local start_col = decorations.require_text_start(line, marker.text, 0, ('%s marker geometry'):format(key))
  decorations.apply_color_cell(instance, state.buf, marker.line - 1, start_col, marker.text, marker.value, marker.field)
end

function M.render(instance)
  local state = render_state(instance)
  local field = current_field(state)
  local width = buffer.prepare(instance)
  if not width then
    return
  end

  local lines
  local geometry
  local results_top
  local detail_result
  local dynamic_preview_snapshot = dynamic_preview.begin_render(instance)
  local render_ok, render_err = xpcall(function()
    lines = {}
    geometry = buffer.new_geometry()
    results_top = buffer.append_search_inputs(instance, lines, geometry, width)
    detail_result = detail_scene.current_result(instance)

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

    buffer.replace(instance, lines, geometry, function()
      decorations.apply_workbench_line_highlights(instance, lines, results_top)

      decorations.set_input_header(instance, geometry.name, ui_fields.search_prefixes.name)
      decorations.set_input_header(instance, geometry.color, ui_fields.search_prefixes.color)

      if detail_result then
        decorations.set_detail_menu_header(instance, results_top, detail_result)
        apply_color_marker(instance, lines, geometry, 'color_sample')
        apply_color_marker(instance, lines, geometry, 'color_swatch')

        decorations.apply_detail_menu_highlights(instance, geometry.detail_menu, session.is_dirty(detail_result.name))
      end

      decorations.refresh_input_placeholders(instance)
      dynamic_preview.tick(instance, vim.uv.hrtime() / 1000000)
      dynamic_preview.sync(instance)
    end)
  end, debug.traceback)
  if not render_ok then
    local restored, restore_err = dynamic_preview.restore_render(instance, dynamic_preview_snapshot)
    if not restored then
      render_err = ('%s; rollback errors: %s'):format(render_err, tostring(restore_err))
    end
    error(render_err, 0)
  end
end

return M
