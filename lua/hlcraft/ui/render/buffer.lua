local render_util = require('hlcraft.render.util')
local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local input_sequence = require('hlcraft.ui.input.sequence')
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
  return numbers.assert_non_negative_integer(instance.ns, 'render buffer namespace', 3)
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
  return numbers.assert_positive_integer(value, label, 3)
end

local function string_list(lines, label)
  return render_util.string_list(lines, label, 3)
end

local function append_rollback_errors(err, rollback_errors)
  if #rollback_errors == 0 then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, table.concat(rollback_errors, '; '))
end

local function geometry_table(geometry)
  if type(geometry) ~= 'table' then
    error('render geometry must be a table', 3)
  end
  return geometry
end

local function optional_callback(callback, label)
  if callback ~= nil and type(callback) ~= 'function' then
    error(('%s must be a function or nil'):format(label), 3)
  end
  return callback
end

local function geometry_inputs(geometry)
  geometry = geometry_table(geometry)
  return tables.assert_sequence(geometry.inputs, 'render geometry inputs', 3)
end

local function validate_input_extmark_rows(state, geometry)
  local line_count = vim.api.nvim_buf_line_count(state.buf)
  for _, field in ipairs(geometry_inputs(geometry)) do
    local line = positive_integer(field.line, 'render geometry input line')
    if line > line_count then
      error('render geometry input line is outside the buffer', 3)
    end
    input_sequence.name(field)
  end
end

local function snapshot_namespace_extmarks(buf, ns)
  local marks = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
    local details = vim.deepcopy(mark[4] or {})
    details.ns_id = nil
    details.id = mark[1]
    marks[#marks + 1] = {
      row = mark[2],
      col = mark[3],
      opts = details,
    }
  end
  return marks
end

local function restore_namespace_extmarks(buf, ns, marks)
  local errors = {}
  for _, mark in ipairs(marks) do
    local ok, err = pcall(vim.api.nvim_buf_set_extmark, buf, ns, mark.row, mark.col, mark.opts)
    if not ok then
      errors[#errors + 1] = tostring(err)
    end
  end
  return errors
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
  local previous_rendering = state.rendering
  state.rendering = true
  local ok, err = xpcall(function()
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  end, debug.traceback)
  state.rendering = previous_rendering
  if not ok then
    error(err, 0)
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
  return math.max(50, vim.api.nvim_win_get_width(win) - 1)
end

function M.finish(instance, geometry)
  local state = instance_state(instance)
  local ns = instance_namespace(instance)
  geometry = geometry_table(geometry)
  geometry_inputs(geometry)
  validate_input_extmark_rows(state, geometry)

  local snapshot = {
    extmark_ids = state.extmark_ids,
    geometry = state.geometry,
    input_marks = state.input_marks,
    placeholder_marks = state.placeholder_marks,
  }
  local input_extmark_transaction
  local ok, err = xpcall(function()
    theme.apply(ns)
    state.geometry = geometry
    input_extmark_transaction = buffer_fields.set_extmarks(instance, { defer_delete = true })
    vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
    require('hlcraft.ui.dynamic_preview').reset_marks(instance)
    state.input_marks = {}
    state.placeholder_marks = {}
    if input_extmark_transaction then
      input_extmark_transaction.commit()
    end
  end, debug.traceback)
  if not ok then
    local rollback_errors = {}
    if input_extmark_transaction then
      local rolled_back, rollback_err = xpcall(input_extmark_transaction.rollback, debug.traceback)
      if not rolled_back then
        rollback_errors[#rollback_errors + 1] = tostring(rollback_err)
      end
    end
    state.extmark_ids = snapshot.extmark_ids
    state.geometry = snapshot.geometry
    state.input_marks = snapshot.input_marks
    state.placeholder_marks = snapshot.placeholder_marks
    error(append_rollback_errors(err, rollback_errors), 0)
  end
end

function M.replace(instance, lines, geometry, after)
  local state = instance_state(instance)
  local ns = instance_namespace(instance)
  after = optional_callback(after, 'render replace callback')
  local previous_lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local previous_geometry = vim.deepcopy(state.geometry)
  local previous_input_marks = state.input_marks
  local previous_placeholder_marks = state.placeholder_marks
  local previous_namespace_extmarks = snapshot_namespace_extmarks(state.buf, ns)
  local ok, err = xpcall(function()
    M.set_lines(instance, lines)
    M.finish(instance, geometry)
    if after then
      after()
    end
  end, debug.traceback)
  if not ok then
    local rollback_errors = {}
    local restored_lines, restore_lines_err = xpcall(function()
      M.set_lines(instance, previous_lines)
    end, debug.traceback)
    if not restored_lines then
      rollback_errors[#rollback_errors + 1] = tostring(restore_lines_err)
    end
    if restored_lines and type(previous_geometry) == 'table' then
      local restored_geometry, restore_geometry_err = xpcall(function()
        M.finish(instance, previous_geometry)
      end, debug.traceback)
      if not restored_geometry then
        rollback_errors[#rollback_errors + 1] = tostring(restore_geometry_err)
      else
        state.input_marks = previous_input_marks
        state.placeholder_marks = previous_placeholder_marks
        vim.list_extend(rollback_errors, restore_namespace_extmarks(state.buf, ns, previous_namespace_extmarks))
      end
    end
    error(append_rollback_errors(err, rollback_errors), 0)
  end
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
