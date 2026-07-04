local render_util = require('hlcraft.render.util')
local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local ui_state = require('hlcraft.ui.state')
local theme = require('hlcraft.ui.theme')
local window = require('hlcraft.ui.workspace.window')

local M = {}

M.new_geometry = ui_state.geometry

function M.set_lines(instance, lines)
  instance.state.rendering = true
  local ok, err = pcall(function()
    vim.bo[instance.state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(instance.state.buf, 0, -1, false, lines)
  end)
  instance.state.rendering = false
  if not ok then
    vim.notify(('hlcraft: buffer render failed: %s'):format(tostring(err)), vim.log.levels.WARN)
  end
end

function M.prepare(instance)
  if not window.is_valid_buf(instance.state.buf) then
    return nil
  end
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end
  instance.state.dynamic_preview_items = {}
  return math.max(50, vim.api.nvim_win_get_width(win) - 1)
end

function M.finish(instance, geometry)
  vim.api.nvim_buf_clear_namespace(instance.state.buf, instance.ns, 0, -1)
  require('hlcraft.ui.dynamic_preview').reset_marks(instance)
  instance.state.input_marks = {}
  instance.state.placeholder_marks = {}
  theme.apply(instance.ns)
  instance.state.geometry = geometry
  buffer_fields.set_extmarks(instance)
end

--- Create a new input field descriptor table.
--- @param name string Field name
--- @param kind string Field kind ('name', 'color', 'detail')
--- @param line number 1-based line number where field starts
--- @param extra table|nil Additional properties (key, label, width)
--- @return table Field descriptor
function M.new_input_field(name, kind, line, extra)
  return vim.tbl_extend('force', {
    name = name,
    kind = kind,
    line = line,
  }, extra or {})
end

--- Append an input field line to the lines list and register it in geometry.
--- @param lines string[] Mutable list of buffer lines being built
--- @param geometry table Mutable geometry table to register the field in
--- @param name string Field name
--- @param kind string Field kind ('name', 'color', 'detail')
--- @param value string Current value to display
--- @param extra table|nil Additional properties (key, label, width)
--- @return table The created field descriptor
function M.append_input(lines, geometry, name, kind, value, extra)
  local field = M.new_input_field(name, kind, #lines + 1, extra)
  geometry[name] = field
  geometry.inputs[#geometry.inputs + 1] = field
  lines[#lines + 1] =
    render_util.truncate(buffer_fields.normalize_single_line(value), extra and extra.width or math.huge)
  return field
end

--- Append the shared search input block and return the first content line.
--- @param instance table The Instance object holding UI state
--- @param lines string[] Mutable list of buffer lines being built
--- @param geometry table Mutable geometry table to register input fields in
--- @param width number Render width
--- @return number results_top 1-based line where scene content starts
function M.append_search_inputs(instance, lines, geometry, width)
  lines[#lines + 1] = ''
  M.append_input(lines, geometry, 'name', 'name', instance.state.name_query, { width = width })
  M.append_input(lines, geometry, 'color', 'color', instance.state.color_query, { width = width })
  lines[#lines + 1] = ''
  return #lines + 1
end

function M.absolutize_editor_geometry(geometry, results_top)
  for _, row in pairs(geometry.editor_rows) do
    row.line = results_top + row.line - 1
  end
  for _, key in ipairs({ 'color_sample', 'color_swatch' }) do
    if geometry[key] then
      geometry[key].line = results_top + geometry[key].line - 1
    end
  end
end

function M.absolutize_detail_menu_geometry(geometry, results_top)
  for _, row in pairs(geometry.detail_menu) do
    row.line = results_top + row.line - 1
  end
end

return M
