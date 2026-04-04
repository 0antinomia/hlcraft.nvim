local color = require('hlcraft.color')
local config = require('hlcraft.config')
local overrides = require('hlcraft.overrides')
local ui_fields = require('hlcraft.ui.fields')
local workspace = require('hlcraft.ui.workspace')
local input_model = require('hlcraft.ui.input.model')

local M = {}

local function get_results_state()
  return require('hlcraft.ui.state.results')
end

--- Parse a boolean form value string into a true/false/nil result
--- @param instance table The Instance object holding UI state
--- @param value string|nil Raw string value from the form
--- @param label string Field label for error messages
--- @return boolean|nil Parsed boolean value, or nil if empty
--- @return string|nil Error message if value is invalid
function M.parse_form_boolean(instance, value, label)
  local normalized = vim.trim((value or '')):lower()
  if normalized == '' then
    return nil, nil
  end
  if normalized == 'true' or normalized == 'on' or normalized == 'yes' then
    return true, nil
  end
  if normalized == 'false' or normalized == 'off' or normalized == 'no' then
    return false, nil
  end
  return nil, ('%s must be true, false, or empty'):format(label)
end

--- Format a form value for display in a detail input field
--- @param value any Value to format (nil, boolean, or other)
--- @return string Formatted string representation
local function format_form_value(value)
  if value == nil then
    return ''
  end
  if type(value) == 'boolean' then
    return value and 'true' or 'false'
  end
  return tostring(value)
end

--- Build a snapshot of current form values, merging runtime overrides with user edits
--- @param instance table The Instance object holding UI state
--- @param result table Highlight group result being edited
--- @return table Map of field names to string values
function M.snapshot(instance, result)
  local runtime_override = overrides.get(result.name)
  local runtime_group = overrides.get_runtime_group(result.name)
  local values = {
    group = runtime_group ~= config.default_group_name() and runtime_group or '',
    fg = format_form_value(runtime_override.fg),
    bg = format_form_value(runtime_override.bg),
    sp = format_form_value(runtime_override.sp),
    bold = format_form_value(runtime_override.bold),
    italic = format_form_value(runtime_override.italic),
    underline = format_form_value(runtime_override.underline),
    undercurl = format_form_value(runtime_override.undercurl),
    strikethrough = format_form_value(runtime_override.strikethrough),
    blend = format_form_value(runtime_override.blend),
  }

  for _, key in ipairs(ui_fields.detail_order) do
    if instance.state.detail_form[key] ~= nil then
      values[key] = instance.state.detail_form[key]
    end
  end

  return values
end

--- Read current form values from the buffer input fields
--- @param instance table The Instance object holding UI state
--- @return table Map of field names to trimmed string values
function M.values(instance)
  local values = {}
  for _, key in ipairs(ui_fields.detail_order) do
    values[key] = vim.trim(input_model.get_input_value(instance, key))
  end
  return values
end

--- Read form values from buffer and store in instance.state.detail_form
--- @param instance table The Instance object holding UI state
--- @return nil
function M.sync_from_buffer(instance)
  if not instance.state.detail_index then
    return
  end
  instance.state.detail_form = M.values(instance)
end

--- Check if detail form layout has shifted (fields on wrong rows) due to editing
--- @param instance table The Instance object holding UI state
--- @return boolean True if any field is out of expected position
function M.is_layout_dirty(instance)
  if not instance.state.detail_index or not workspace.is_valid_buf(instance.state.buf) then
    return false
  end

  local prev_end = nil
  for _, key in ipairs(ui_fields.detail_order) do
    local start_row, end_row = input_model.get_input_pos(instance, key)
    if not (start_row and end_row) then
      return true
    end
    if end_row ~= start_row + 1 then
      return true
    end
    if prev_end ~= nil and start_row ~= prev_end then
      return true
    end
    prev_end = end_row
  end

  return false
end

--- Re-render the detail form, preserving cursor position and insert mode
--- @param instance table The Instance object holding UI state
--- @return nil
function M.rerender(instance)
  local win = workspace.get_win(instance)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local field = input_model.get_input_field_at_row(instance, cursor[1] - 1)
  local field_key = field and (field.key or field.name) or nil
  local in_insert = vim.fn.mode():lower():find('i') ~= nil

  M.sync_from_buffer(instance)
  instance:rerender()

  if field_key then
    local target = instance.state.geometry.detail_fields[field_key]
    if target then
      local line = vim.api.nvim_buf_get_lines(instance.state.buf, target.line - 1, target.line, false)[1] or ''
      vim.api.nvim_win_set_cursor(win, { target.line, math.min(cursor[2], #line) })
    end
  end

  if in_insert then
    vim.cmd('startinsert')
  end
end

--- Validate and apply the detail form as an override for the current highlight group
--- @param instance table The Instance object holding UI state
--- @return nil
function M.apply(instance)
  local results_state = get_results_state()
  local result = results_state.current_detail_result(instance)
  if not result then
    return
  end

  local values = M.values(instance)
  local normalized_colors = {}
  local styles = {}

  for _, key in ipairs({ 'bold', 'italic', 'underline', 'undercurl', 'strikethrough' }) do
    local parsed, err = M.parse_form_boolean(instance, values[key], key)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    styles[key] = parsed
  end

  local blend = nil
  if vim.trim(values.blend or '') ~= '' then
    local number_value = tonumber(values.blend)
    if number_value == nil or number_value < 0 or number_value > 100 then
      vim.notify('Blend must be a number between 0 and 100', vim.log.levels.ERROR)
      return
    end
    blend = math.floor(number_value)
  end

  local has_override = false
  for _, key in ipairs({ 'fg', 'bg', 'sp' }) do
    local input = vim.trim(values[key] or '')
    if input ~= '' then
      local normalized, err = color.normalize(input)
      if err then
        vim.notify(err, vim.log.levels.ERROR)
        return
      end
      normalized_colors[key] = normalized
      has_override = true
    end
  end

  if not has_override then
    for _, key in ipairs({ 'bold', 'italic', 'underline', 'undercurl', 'strikethrough' }) do
      if styles[key] ~= nil then
        has_override = true
        break
      end
    end
  end
  if not has_override and blend ~= nil then
    has_override = true
  end

  overrides.clear(result.name)
  if has_override then
    overrides.set_group(result.name, values.group)

    for _, key in ipairs({ 'fg', 'bg', 'sp' }) do
      if normalized_colors[key] ~= nil then
        local ok, err = overrides.set_color(result.name, key, normalized_colors[key])
        if not ok then
          vim.notify(err, vim.log.levels.ERROR)
          return
        end
      end
    end

    for _, key in ipairs({ 'bold', 'italic', 'underline', 'undercurl', 'strikethrough' }) do
      if styles[key] ~= nil then
        local ok, err = overrides.set_style(result.name, key, styles[key])
        if not ok then
          vim.notify(err, vim.log.levels.ERROR)
          return
        end
      end
    end

    if blend ~= nil then
      local ok, err = overrides.set_blend(result.name, blend)
      if not ok then
        vim.notify(err, vim.log.levels.ERROR)
        return
      end
    end
  end

  local save_ok, save_err = overrides.save()
  if not save_ok then
    vim.notify(('hlcraft: failed to save overrides: %s'):format(tostring(save_err)), vim.log.levels.ERROR)
    return
  end
  results_state.refresh(instance, result.name, true)
end

return M
