local workspace = require('hlcraft.ui.workspace')

local M = {}

--- Determine which UI area (name, color, detail, results) the cursor is in
--- @param instance table The Instance object holding UI state
--- @param row1 number 1-based row number
--- @return string|nil Area name ('name', 'color', 'detail', 'results')
--- @return table|nil Extra context: field for input areas, result index for results
function M.current_area(instance, row1)
  local input = M.get_input_at_row(instance, row1 - 1)
  if input then
    local field = input.field
    if field.kind == 'detail' then
      return 'detail', field
    end
    return field.kind, field
  end
  if instance.state.geometry.result_lines[row1] then
    return 'results', instance.state.geometry.result_lines[row1]
  end
end

--- Collapse newlines and carriage returns into a single space
--- @param value any Value to normalize
--- @return string Single-line string
function M.normalize_single_line(value)
  local text = tostring(value or ''):gsub('[\r\n]+', ' ')
  return text
end

--- Get the input field descriptor at a given 0-based row
--- @param instance table The Instance object holding UI state
--- @param row0 number 0-based row number
--- @return table|nil Field descriptor with name, kind, line, etc.
function M.get_input_field_at_row(instance, row0)
  for _, field in ipairs(instance.state.geometry.inputs or {}) do
    if field.line - 1 == row0 then
      return field
    end
  end
end

--- Set extmarks for all input fields to track their boundaries across re-renders
--- @param instance table The Instance object holding UI state
--- @return nil
function M.set_input_extmarks(instance)
  if not workspace.is_valid_buf(instance.state.buf) then
    return
  end

  instance.state.extmark_ids = {}
  local inputs = instance.state.geometry.inputs or {}
  for _, field in ipairs(inputs) do
    local name = field.key or field.name
    instance.state.extmark_ids[name .. ':start'] =
      vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, field.line - 1, 0, {
        right_gravity = false,
      })
    instance.state.extmark_ids[name .. ':end'] =
      vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, field.line, 0, {
        right_gravity = false,
      })
  end
end

--- Get the start and end row positions of a named input field via extmarks
--- @param instance table The Instance object holding UI state
--- @param name string Input field name
--- @return number|nil start_row 0-based start row
--- @return number|nil end_row 0-based boundary row (one past last content line)
--- @return table|nil field Field descriptor
function M.get_input_pos(instance, name)
  local field = nil

  for _, input in ipairs(instance.state.geometry.inputs or {}) do
    local input_name = input.key or input.name
    if input_name == name then
      field = input
      break
    end
  end

  if not field then
    return nil, nil, field
  end

  local start_id = instance.state.extmark_ids[name .. ':start']
  local end_id = instance.state.extmark_ids[name .. ':end']
  if not start_id or not end_id then
    return nil, nil, field
  end

  local start_mark = vim.api.nvim_buf_get_extmark_by_id(instance.state.buf, instance.ns, start_id, {})
  local end_mark = vim.api.nvim_buf_get_extmark_by_id(instance.state.buf, instance.ns, end_id, {})
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

--- Set the value of a named input field, replacing existing content
--- @param instance table The Instance object holding UI state
--- @param name string Input field name
--- @param value string|nil New value to set
--- @param clear_old boolean Whether to clear and proceed even if value is nil
--- @return nil
function M.fill_input(instance, name, value, clear_old)
  if value == nil and not clear_old then
    return
  end

  local start_row, _, field = M.get_input_pos(instance, name)
  if not (start_row and field) then
    return
  end

  local old_num_lines = #M.get_input_lines(instance, name)
  local new_lines = vim.split(value or '', '\n')
  vim.api.nvim_buf_set_lines(instance.state.buf, start_row, start_row + old_num_lines - 1, true, new_lines)
  vim.api.nvim_buf_set_lines(instance.state.buf, start_row + #new_lines, start_row + #new_lines + 1, true, {})
end

--- Get the input field data at a given 0-based row, including value and boundary info
--- @param instance table The Instance object holding UI state
--- @param row0 number 0-based row number
--- @return table|nil Input data with name, value, start_row, end_row, field keys
function M.get_input_at_row(instance, row0)
  for _, field in ipairs(instance.state.geometry.inputs or {}) do
    local name = field.key or field.name
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
  return vim.api.nvim_buf_get_lines(instance.state.buf, field.line - 1, field.line, false)[1] or ''
end

--- Read name and color query values from the buffer into instance state
--- @param instance table The Instance object holding UI state
--- @return nil
function M.sync_queries_from_buffer(instance)
  if instance.state.rendering or not workspace.is_valid_buf(instance.state.buf) or instance.state.detail_index then
    return
  end
  instance.state.name_query = M.get_input_value(instance, 'name')
  instance.state.color_query = M.get_input_value(instance, 'color')
end

return M
