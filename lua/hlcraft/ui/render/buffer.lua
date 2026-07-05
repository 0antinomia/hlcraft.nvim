local notify = require('hlcraft.notify')
local render_util = require('hlcraft.render.util')
local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local ui_state = require('hlcraft.ui.state')
local theme = require('hlcraft.ui.theme')
local window = require('hlcraft.ui.workspace.window')

local M = {}

M.new_geometry = ui_state.geometry

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('render buffer requires an instance', 3)
  end
  return instance.state
end

local function instance_namespace(instance)
  if type(instance.ns) ~= 'number' then
    error('render buffer namespace must be a number', 3)
  end
  if not numbers.is_finite(instance.ns) or math.floor(instance.ns) ~= instance.ns or instance.ns < 0 then
    error('render buffer namespace must be a non-negative finite integer', 3)
  end
  return instance.ns
end

local function optional_table(value, label)
  if value == nil then
    return {}
  end
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  return value
end

local function non_empty_string(value, label)
  if type(value) ~= 'string' or value == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return value
end

local function input_value(value)
  if type(value) ~= 'string' then
    error('input field value must be a string', 3)
  end
  return value
end

local function positive_integer(value, label)
  if type(value) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  if not numbers.is_finite(value) or math.floor(value) ~= value or value < 1 then
    error(('%s must be a positive finite integer'):format(label), 3)
  end
  return value
end

local function string_list(lines, label)
  return render_util.string_list(lines, label, 3)
end

local function geometry_table(geometry)
  if type(geometry) ~= 'table' then
    error('render geometry must be a table', 3)
  end
  return geometry
end

local function geometry_inputs(geometry)
  geometry = geometry_table(geometry)
  return tables.assert_sequence(geometry.inputs, 'render geometry inputs', 3)
end

local function geometry_rows(geometry, key)
  geometry = geometry_table(geometry)
  local rows = geometry[key]
  if type(rows) ~= 'table' then
    error(('render geometry %s must be a table'):format(key), 3)
  end
  return rows
end

local function input_width(extra)
  if type(extra) ~= 'table' or extra.width == nil then
    error('input field width is required', 3)
  end
  return positive_integer(extra.width, 'input field width')
end

local function offset_line(row, results_top, label)
  if type(row) ~= 'table' then
    error(('%s row must be a table'):format(label), 3)
  end
  row.line = results_top + positive_integer(row.line, ('%s row line'):format(label)) - 1
end

function M.set_lines(instance, lines)
  local state = instance_state(instance)
  lines = string_list(lines, 'render lines')
  state.rendering = true
  local ok, err = pcall(function()
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  end)
  state.rendering = false
  if not ok then
    notify.warn(('buffer render failed: %s'):format(tostring(err)))
  end
end

function M.prepare(instance)
  local state = instance_state(instance)
  if not window.is_valid_buf(state.buf) then
    return nil
  end
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end
  require('hlcraft.ui.dynamic_preview').reset_items(instance)
  return math.max(50, vim.api.nvim_win_get_width(win) - 1)
end

function M.finish(instance, geometry)
  local state = instance_state(instance)
  local ns = instance_namespace(instance)
  geometry = geometry_table(geometry)
  geometry_inputs(geometry)
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  require('hlcraft.ui.dynamic_preview').reset_marks(instance)
  state.input_marks = {}
  state.placeholder_marks = {}
  theme.apply(ns)
  state.geometry = geometry
  buffer_fields.set_extmarks(instance)
end

--- Create a new input field descriptor table.
--- @param name string Field name
--- @param kind string Field kind ('name', 'color', 'detail')
--- @param line number 1-based line number where field starts
--- @param extra table|nil Additional properties (key, label, width)
--- @return table Field descriptor
function M.new_input_field(name, kind, line, extra)
  extra = optional_table(extra, 'input field extra')
  return vim.tbl_extend('force', {
    name = non_empty_string(name, 'input field name'),
    kind = non_empty_string(kind, 'input field kind'),
    line = positive_integer(line, 'input field line'),
  }, extra)
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
  lines = string_list(lines, 'render lines')
  local inputs = geometry_inputs(geometry)
  local width = input_width(extra)
  value = input_value(value)
  if geometry[name] ~= nil then
    error(('render geometry input already exists: %s'):format(name), 3)
  end
  local field = M.new_input_field(name, kind, #lines + 1, extra)
  geometry[name] = field
  inputs[#inputs + 1] = field
  lines[#lines + 1] = render_util.truncate(buffer_fields.normalize_single_line(value), width)
  return field
end

--- Append the shared search input block and return the first content line.
--- @param instance table The Instance object holding UI state
--- @param lines string[] Mutable list of buffer lines being built
--- @param geometry table Mutable geometry table to register input fields in
--- @param width number Render width
--- @return number results_top 1-based line where scene content starts
function M.append_search_inputs(instance, lines, geometry, width)
  local state = instance_state(instance)
  lines = string_list(lines, 'render lines')
  geometry_inputs(geometry)
  width = positive_integer(width, 'search input width')
  lines[#lines + 1] = ''
  M.append_input(lines, geometry, 'name', 'name', state.name_query, { width = width })
  M.append_input(lines, geometry, 'color', 'color', state.color_query, { width = width })
  lines[#lines + 1] = ''
  return #lines + 1
end

function M.absolutize_editor_geometry(geometry, results_top)
  results_top = positive_integer(results_top, 'editor geometry result top')
  for _, row in pairs(geometry_rows(geometry, 'editor_rows')) do
    offset_line(row, results_top, 'editor geometry')
  end
  for _, key in ipairs({ 'color_sample', 'color_swatch' }) do
    if geometry[key] then
      offset_line(geometry[key], results_top, key)
    end
  end
end

function M.absolutize_detail_menu_geometry(geometry, results_top)
  results_top = positive_integer(results_top, 'detail menu result top')
  for _, row in pairs(geometry_rows(geometry, 'detail_menu')) do
    offset_line(row, results_top, 'detail menu geometry')
  end
end

return M
