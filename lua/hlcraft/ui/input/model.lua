local input_sequence = require('hlcraft.ui.input.sequence')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local window = require('hlcraft.ui.workspace.window')
local buffer_lines = require('hlcraft.ui.buffer_lines')

local M = {}
local input_ns = vim.api.nvim_create_namespace('hlcraft-ui-input')

local function field_name(field)
  return input_sequence.name(field)
end

local function assert_input_field(field)
  if type(field) ~= 'table' then
    error('input field must be a table', 3)
  end
  return field
end

local function assert_input_value(value)
  if type(value) ~= 'string' then
    error('input value must be a string', 3)
  end
end

local function assert_clear_old(clear_old)
  if type(clear_old) ~= 'boolean' then
    error('input clear_old flag must be boolean', 3)
  end
  return clear_old
end

local function optional_extmark_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error('input extmark options must be a table', 3)
  end
  if opts.defer_delete ~= nil and type(opts.defer_delete) ~= 'boolean' then
    error('input extmark defer_delete option must be boolean', 3)
  end
  return opts
end

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('input model requires an instance', 3)
  end
  return instance.state
end

local function assert_input_name(name)
  if type(name) ~= 'string' or name == '' then
    error('input name must be a non-empty string', 3)
  end
  return name
end

local function assert_row0(row0)
  if type(row0) ~= 'number' then
    error('input row must be a number', 3)
  end
  if not numbers.is_integer(row0, 0) then
    error('input row must be a non-negative finite integer', 3)
  end
  return row0
end

local function assert_row1(row1)
  if type(row1) ~= 'number' then
    error('input row must be a number', 3)
  end
  if not numbers.is_integer(row1, 1) then
    error('input row must be a positive finite integer', 3)
  end
  return row1
end

local function result_index(value)
  if type(value) ~= 'number' then
    error('input result index must be a number', 3)
  end
  if not numbers.is_integer(value, 1) then
    error('input result index must be a positive finite integer', 3)
  end
  return value
end

local function assert_namespace(ns)
  if type(ns) ~= 'number' then
    error('input namespace must be a number', 3)
  end
  if not numbers.is_integer(ns, 0) then
    error('input namespace must be a non-negative finite integer', 3)
  end
  return ns
end

local function input_namespace(instance)
  if instance.input_ns ~= nil then
    return assert_namespace(instance.input_ns)
  end
  assert_namespace(instance.ns)
  return input_ns
end

local function extmark_id(value, label)
  if value == nil then
    return nil
  end
  if type(value) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  if not numbers.is_integer(value, 1) then
    error(('%s must be a positive finite integer'):format(label), 3)
  end
  return value
end

local function input_geometry(instance)
  local state = instance_state(instance)
  if type(state.geometry) ~= 'table' then
    error('input geometry must be a table', 3)
  end
  return state.geometry
end

local function geometry_inputs(instance)
  local inputs = input_geometry(instance).inputs
  return tables.assert_sequence(inputs, 'input geometry inputs', 3)
end

local function geometry_result_lines(instance)
  local result_lines = input_geometry(instance).result_lines
  if type(result_lines) ~= 'table' then
    error('input geometry result lines must be a table', 3)
  end
  return result_lines
end

local function extmark_ids(instance)
  local ids = instance_state(instance).extmark_ids
  if type(ids) ~= 'table' then
    error('input extmark ids must be a table', 3)
  end
  return ids
end

local function find_input_field(instance, name)
  name = assert_input_name(name)
  for _, input in ipairs(geometry_inputs(instance)) do
    if field_name(input) == name then
      return input
    end
  end
  return nil
end

local function delete_extmark_ids(buf, ns, ids)
  for _, mark_id in pairs(ids) do
    if type(mark_id) == 'number' then
      pcall(vim.api.nvim_buf_del_extmark, buf, ns, mark_id)
    end
  end
end

local function snapshot_tracked_extmarks(buf, ns, ids)
  local tracked = {}
  if type(ids) ~= 'table' then
    return tracked
  end
  for _, mark_id in pairs(ids) do
    if type(mark_id) == 'number' then
      local ok, mark = pcall(vim.api.nvim_buf_get_extmark_by_id, buf, ns, mark_id, {})
      if ok and mark[1] ~= nil and mark[2] ~= nil then
        tracked[#tracked + 1] = {
          id = mark_id,
          row = mark[1],
          col = mark[2],
        }
      end
    end
  end
  return tracked
end

local function restore_tracked_extmarks(buf, ns, tracked)
  local errors = {}
  for _, mark in ipairs(tracked) do
    local ok, err = pcall(vim.api.nvim_buf_set_extmark, buf, ns, mark.row, mark.col, {
      id = mark.id,
      right_gravity = false,
    })
    if not ok then
      errors[#errors + 1] = tostring(err)
    end
  end
  return errors
end

local function append_rollback_errors(err, rollback_errors)
  if #rollback_errors == 0 then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, table.concat(rollback_errors, '; '))
end

--- Determine which UI area (name, color, detail, results) the cursor is in
--- @param instance table The Instance object holding UI state
--- @param row1 number 1-based row number
--- @return string|nil Area name ('name', 'color', 'detail', 'results')
--- @return table|nil Extra context: field for input areas, result index for results
function M.current_area(instance, row1)
  row1 = assert_row1(row1)
  local input = M.get_input_at_row(instance, row1 - 1)
  if input then
    local field = input.field
    if field.kind == 'detail' then
      return 'detail', field
    end
    return field.kind, field
  end
  local result_lines = geometry_result_lines(instance)
  if result_lines[row1] ~= nil then
    return 'results', result_index(result_lines[row1])
  end
end

--- Collapse newlines and carriage returns into a single space
--- @param value string Value to normalize
--- @return string Single-line string
function M.normalize_single_line(value)
  assert_input_value(value)
  return (value:gsub('[\r\n]+', ' '))
end

--- Set extmarks for all input fields to track their boundaries across re-renders
--- @param instance table The Instance object holding UI state
--- @param opts table|nil Options: defer_delete keeps old extmarks until commit()
--- @return table|nil transaction Deferred commit/rollback hooks when defer_delete is true
function M.set_input_extmarks(instance, opts)
  local state = instance_state(instance)
  opts = optional_extmark_opts(opts)
  if not window.is_valid_buf(state.buf) then
    return
  end
  local ns = input_namespace(instance)
  local previous_extmark_ids = state.extmark_ids
  local previous_extmark_values = previous_extmark_ids
  if previous_extmark_values == nil then
    previous_extmark_values = {}
  elseif type(previous_extmark_values) ~= 'table' then
    error('input extmark ids must be a table', 3)
  end
  local line_count = vim.api.nvim_buf_line_count(state.buf)
  local inputs = {}

  for _, field in ipairs(geometry_inputs(instance)) do
    local name = field_name(field)
    local row1 = assert_row1(field.line)
    if row1 > line_count then
      error('input extmark line is outside the buffer', 3)
    end
    inputs[#inputs + 1] = {
      name = name,
      row1 = row1,
    }
  end

  local next_extmark_ids = {}
  local created_extmark_ids = {}
  local ok, err = xpcall(function()
    for _, input in ipairs(inputs) do
      local start_id = vim.api.nvim_buf_set_extmark(state.buf, ns, input.row1 - 1, 0, {
        right_gravity = false,
      })
      next_extmark_ids[input.name .. ':start'] = start_id
      created_extmark_ids[#created_extmark_ids + 1] = start_id
      local end_id = vim.api.nvim_buf_set_extmark(state.buf, ns, input.row1, 0, {
        right_gravity = false,
      })
      next_extmark_ids[input.name .. ':end'] = end_id
      created_extmark_ids[#created_extmark_ids + 1] = end_id
    end
  end, debug.traceback)
  if not ok then
    delete_extmark_ids(state.buf, ns, created_extmark_ids)
    state.extmark_ids = previous_extmark_ids
    error(err, 0)
  end

  state.extmark_ids = next_extmark_ids
  if opts.defer_delete then
    local closed = false
    return {
      commit = function()
        if closed then
          return
        end
        closed = true
        delete_extmark_ids(state.buf, ns, previous_extmark_values)
      end,
      rollback = function()
        if closed then
          return
        end
        closed = true
        delete_extmark_ids(state.buf, ns, next_extmark_ids)
        state.extmark_ids = previous_extmark_ids
      end,
    }
  end
  delete_extmark_ids(state.buf, ns, previous_extmark_values)
end

--- Get the start and end row positions of a named input field via extmarks
--- @param instance table The Instance object holding UI state
--- @param name string Input field name
--- @return number|nil start_row 0-based start row
--- @return number|nil end_row 0-based boundary row (one past last content line)
--- @return table|nil field Field descriptor
function M.get_input_pos(instance, name)
  local field = find_input_field(instance, name)
  if not field then
    return nil, nil, field
  end

  local ids = extmark_ids(instance)
  local start_id = extmark_id(ids[name .. ':start'], 'input start extmark id')
  local end_id = extmark_id(ids[name .. ':end'], 'input end extmark id')
  if not start_id or not end_id then
    return nil, nil, field
  end

  local state = instance_state(instance)
  if not window.is_valid_buf(state.buf) then
    error('input model requires a valid buffer', 3)
  end
  local ns = input_namespace(instance)
  local start_mark = vim.api.nvim_buf_get_extmark_by_id(state.buf, ns, start_id, {})
  local end_mark = vim.api.nvim_buf_get_extmark_by_id(state.buf, ns, end_id, {})
  local start_row = start_mark[1]
  local end_row = end_mark[1]
  return start_row, end_row, field
end

--- Get the buffer lines for a named input field
--- @param instance table The Instance object holding UI state
--- @param name string Input field name
--- @return string[] Lines of text in the input field
--- @return table|nil field Field descriptor
function M.get_input_lines(instance, name)
  local start_row, end_row, field = M.get_input_pos(instance, name)
  if not (start_row and end_row and field) then
    return { '' }, field
  end

  return vim.api.nvim_buf_get_lines(instance.state.buf, start_row, end_row, false), field
end

--- Get the normalized single-line value of a named input field
--- @param instance table The Instance object holding UI state
--- @param name string Input field name
--- @return string Normalized value with newlines collapsed to spaces
function M.get_input_value(instance, name)
  local lines = M.get_input_lines(instance, name)
  return M.normalize_single_line(table.concat(lines, ' '))
end

--- Remove the trailing empty physical line from an input field.
--- @param instance table The Instance object holding UI state
--- @param name string Input field name
--- @return boolean removed Whether a line was removed
function M.remove_trailing_empty_line(instance, name)
  local _, end_boundary_row, field = M.get_input_pos(instance, name)
  if not (end_boundary_row and field) then
    return false
  end

  local lines = M.get_input_lines(instance, name)
  if #lines <= 1 or lines[#lines] ~= '' then
    return false
  end

  vim.api.nvim_buf_set_lines(instance.state.buf, end_boundary_row - 1, end_boundary_row, true, {})
  return true
end

--- Set the value of a named input field, replacing existing content
--- @param instance table The Instance object holding UI state
--- @param name string Input field name
--- @param value string|nil New value to set
--- @param clear_old boolean Whether to clear and proceed even if value is nil
--- @return boolean changed Whether the buffer was changed
function M.fill_input(instance, name, value, clear_old)
  clear_old = assert_clear_old(clear_old)
  if value == nil and not clear_old then
    return false
  end
  if value ~= nil then
    assert_input_value(value)
  end

  local start_row, _, field = M.get_input_pos(instance, name)
  if not (start_row and field) then
    return false
  end

  local old_num_lines = #M.get_input_lines(instance, name)
  local next_value = value
  if next_value == nil then
    next_value = ''
  end
  local new_lines = vim.split(next_value, '\n')
  local previous_lines = vim.api.nvim_buf_get_lines(instance.state.buf, 0, -1, false)
  local ns = input_namespace(instance)
  local previous_extmarks = snapshot_tracked_extmarks(instance.state.buf, ns, instance.state.extmark_ids)
  local ok, err = xpcall(function()
    vim.api.nvim_buf_set_lines(instance.state.buf, start_row, start_row + old_num_lines - 1, true, new_lines)
    vim.api.nvim_buf_set_lines(instance.state.buf, start_row + #new_lines, start_row + #new_lines + 1, true, {})
  end, debug.traceback)
  if not ok then
    local rollback_errors = {}
    local restored_lines, restore_lines_err =
      pcall(vim.api.nvim_buf_set_lines, instance.state.buf, 0, -1, false, previous_lines)
    if not restored_lines then
      rollback_errors[#rollback_errors + 1] = tostring(restore_lines_err)
    end
    vim.list_extend(rollback_errors, restore_tracked_extmarks(instance.state.buf, ns, previous_extmarks))
    error(append_rollback_errors(err, rollback_errors), 0)
  end
  return true
end

--- Get the input field data at a given 0-based row, including value and boundary info
--- @param instance table The Instance object holding UI state
--- @param row0 number 0-based row number
--- @return table|nil Input data with name, value, start_row, end_row, field keys
function M.get_input_at_row(instance, row0)
  row0 = assert_row0(row0)
  for _, field in ipairs(geometry_inputs(instance)) do
    local name = field_name(field)
    local start_row, end_boundary_row = M.get_input_pos(instance, name)
    if start_row and end_boundary_row then
      local end_row = end_boundary_row - 1
      if row0 >= start_row and row0 <= end_row then
        return {
          name = name,
          value = M.get_input_value(instance, name),
          start_row = start_row,
          end_row = end_row,
          field = field,
        }
      end
    end
  end
end

--- Get the text content of the buffer line for a given input field
--- @param instance table The Instance object holding UI state
--- @param field table Field descriptor with a `line` key
--- @return string Text content of the field's line
function M.field_line_text(instance, field)
  local state = instance_state(instance)
  field = assert_input_field(field)
  return buffer_lines.line(state.buf, assert_row1(field.line) - 1, 'input field')
end

--- Read name and color query values from the buffer into instance state
--- @param instance table The Instance object holding UI state
--- @return nil
function M.sync_queries_from_buffer(instance)
  local state = instance_state(instance)
  if state.rendering or not window.is_valid_buf(state.buf) or state.detail_index then
    return
  end
  local name_query = M.get_input_value(instance, 'name')
  local color_query = M.get_input_value(instance, 'color')
  state.name_query = name_query
  state.color_query = color_query
end

return M
