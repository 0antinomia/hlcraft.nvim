local color = require('hlcraft.core.color')
local dynamic_model = require('hlcraft.dynamic.model')
local session = require('hlcraft.ui.session')
local ui_fields = require('hlcraft.ui.fields')
local results_state = require('hlcraft.ui.state.results')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local color_keys = {
  fg = true,
  bg = true,
  sp = true,
}

local channel_shifts = {
  r = 16,
  red = 16,
  g = 8,
  green = 8,
  b = 0,
  blue = 0,
}

local function notify_error(message)
  vim.notify(message, vim.log.levels.ERROR)
end

local function current_result(instance)
  return results_state.current_detail_result(instance)
end

local function current_field(instance)
  return instance.state.field_editor and instance.state.field_editor.field or nil
end

local function current_dynamic(result, key)
  return session.dynamic_value(result.name, key)
end

local function current_dynamic_copy(result, key)
  local dynamic = current_dynamic(result, key)
  if not dynamic then
    return nil
  end
  return vim.deepcopy(dynamic)
end

local function next_mode(mode)
  local modes = ui_fields.dynamic_modes
  for index, candidate in ipairs(modes) do
    if candidate == mode then
      return modes[index + 1] or modes[1]
    end
  end
  return modes[1]
end

local function menu_row_at_cursor(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end

  local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
  for _, row in pairs(instance.state.geometry.detail_menu or {}) do
    if row.line == cursor_line then
      return row
    end
  end
  return nil
end

local function editor_row_at_cursor(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end

  local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
  for key, row in pairs(instance.state.geometry.editor_rows or {}) do
    if row.line == cursor_line then
      row.key = row.key or key
      return row
    end
  end
  return nil
end

local function selected_palette_index(instance, dynamic)
  local editor_row = editor_row_at_cursor(instance)
  local row_key = editor_row and editor_row.key or ''
  local index = tonumber(tostring(row_key):match('^dynamic_palette:(%d+)$'))
  local count = type(dynamic.palette) == 'table' and #dynamic.palette or 0
  if index and dynamic.palette and dynamic.palette[index] then
    return index
  end
  if count == 0 then
    return 1
  end

  local stored = tonumber(instance.state.field_editor.palette_index) or 1
  return math.max(1, math.min(count, stored))
end

local function selected_param_name(instance)
  local editor_row = editor_row_at_cursor(instance)
  local row_key = editor_row and editor_row.key or ''
  return tostring(row_key):match('^dynamic_param:(%w+)$')
end

local function is_finite_number(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function apply_patch(instance, result, patch, preserve_field)
  local ok, err = session.apply_patch(instance, result.name, patch)
  if not ok then
    notify_error(err or 'Failed to update highlight override')
    return false, err
  end

  if preserve_field then
    instance.state.field_editor.field = preserve_field
  end
  return true, nil
end

local function apply_dynamic(instance, result, key, dynamic)
  return apply_patch(instance, result, {
    dynamic = {
      [key] = dynamic,
    },
  }, key)
end

local function jump_to_palette_index(instance, index)
  local row = instance.state.geometry.editor_rows[('dynamic_palette:%d'):format(index)]
  local win = window.get_win(instance)
  if row and window.is_valid_win(win) then
    pcall(vim.api.nvim_win_set_cursor, win, { row.line, 0 })
  end
end

local function fallback_color(result, key)
  if key == 'fg' then
    return result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  end
  if key == 'bg' then
    return result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  end
  return result[key]
end

local function clamp(value, min, max)
  return math.max(min, math.min(max, value))
end

function M.open(instance, key)
  instance.state.field_editor.field = key
  instance:rerender()
end

function M.close(instance)
  instance.state.field_editor.field = nil
  instance:rerender()
end

function M.activate(instance)
  if current_field(instance) == 'group' then
    local editor_row = editor_row_at_cursor(instance)
    local row_key = editor_row and editor_row.key or nil
    if type(row_key) == 'string' and row_key:sub(1, 6) == 'group:' then
      M.set_group(instance, row_key:sub(7))
      return
    end
    if row_key == 'new_group' then
      vim.ui.input({ prompt = 'Group: ' }, function(value)
        if value == nil then
          return
        end
        local ok, err = M.set_group(instance, value)
        if not ok then
          notify_error(err or 'Failed to update group')
        end
      end)
      return
    end
  end

  local row = menu_row_at_cursor(instance)
  local result = current_result(instance)
  if not row or not result then
    return
  end

  if row.kind ~= 'boolean' then
    M.open(instance, row.key)
    return
  end

  local runtime_value = session.draft_entry(result.name)[row.key]
  local next_value = true
  if runtime_value == true then
    next_value = false
  elseif runtime_value == false then
    next_value = vim.NIL
  end

  apply_patch(instance, result, { [row.key] = next_value })
end

function M.set_color(instance, value)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end
  if current_dynamic(result, key) then
    return false, 'Static color controls are disabled in dynamic mode'
  end

  local normalized, err = color.normalize(value)
  if err then
    notify_error(err)
    return false, err
  end

  return apply_patch(instance, result, { [key] = normalized == nil and vim.NIL or normalized }, key)
end

function M.adjust_color(instance, channel, delta)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end
  if current_dynamic(result, key) then
    return false, 'Static color controls are disabled in dynamic mode'
  end

  local shift = channel_shifts[tostring(channel or ''):lower()]
  if not shift then
    return false, ('Unsupported color channel: %s'):format(tostring(channel))
  end

  local current = session.draft_entry(result.name)[key]
  if current == nil then
    current = fallback_color(result, key)
  end
  if current == nil or current == 'NONE' then
    current = '#000000'
  end

  local rgb = color.hex_to_int(current)
  if not rgb then
    return false, ('Cannot adjust invalid color: %s'):format(tostring(current))
  end

  local amount = tonumber(delta) or 0
  local component = math.floor(rgb / (2 ^ shift)) % 256
  local adjusted = clamp(component + amount, 0, 255)
  local next_rgb = rgb + ((adjusted - component) * (2 ^ shift))

  return M.set_color(instance, color.int_to_hex(next_rgb))
end

function M.toggle_dynamic(instance)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end

  local next_value = current_dynamic(result, key) and vim.NIL or dynamic_model.default_spec()
  return apply_patch(instance, result, { dynamic = { [key] = next_value } }, key)
end

function M.cycle_dynamic_mode(instance)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end

  local dynamic = current_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  local next_dynamic = vim.deepcopy(dynamic)
  next_dynamic.mode = next_mode(dynamic.mode)

  return apply_patch(instance, result, {
    dynamic = {
      [key] = next_dynamic,
    },
  }, key)
end

function M.adjust_dynamic_speed(instance, delta)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end

  local dynamic = current_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  local next_dynamic = vim.deepcopy(dynamic)
  next_dynamic.speed = dynamic_model.normalize_speed(dynamic.speed + (tonumber(delta) or 0))

  return apply_patch(instance, result, {
    dynamic = {
      [key] = next_dynamic,
    },
  }, key)
end

function M.set_dynamic_param(instance, name, value)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end
  local dynamic = current_dynamic_copy(result, key)
  if not dynamic or dynamic.mode ~= 'breath' then
    return false, 'No breath dynamic field is active'
  end
  if name ~= 'min' and name ~= 'max' then
    return false, ('Unsupported dynamic param: %s'):format(tostring(name))
  end
  local number_value = tonumber(value)
  if not is_finite_number(number_value) then
    return false, 'Breath dynamic param must be a number'
  end
  dynamic.params = dynamic_model.normalize_params('breath', dynamic.params)
  dynamic.params[name] = number_value
  dynamic.params = dynamic_model.normalize_params('breath', dynamic.params)
  return apply_dynamic(instance, result, key, dynamic)
end

function M.selected_param_name(instance)
  return selected_param_name(instance)
end

M.selected_dynamic_param_name = M.selected_param_name

function M.adjust_dynamic_param(instance, name, delta)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end

  local dynamic = current_dynamic(result, key)
  if not dynamic or dynamic.mode ~= 'breath' then
    return false, 'No breath dynamic field is active'
  end

  local params = dynamic_model.normalize_params('breath', dynamic.params)
  local param_name = name or M.selected_param_name(instance) or 'min'
  if param_name ~= 'min' and param_name ~= 'max' then
    return false, ('Unsupported dynamic param: %s'):format(tostring(param_name))
  end
  return M.set_dynamic_param(instance, param_name, params[param_name] + (tonumber(delta) or 0))
end

function M.select_dynamic_palette(instance, delta)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end
  local dynamic = current_dynamic(result, key)
  if not dynamic or dynamic.mode ~= 'rgb' then
    return false, 'No RGB dynamic field is active'
  end

  local count = #(dynamic.palette or dynamic_model.default_palette())
  local current = selected_palette_index(instance, dynamic)
  local next_index = ((current - 1 + delta) % count) + 1
  instance.state.field_editor.palette_index = next_index
  instance:rerender()
  jump_to_palette_index(instance, next_index)

  return true, nil
end

function M.add_dynamic_palette_color(instance)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end
  local dynamic = current_dynamic_copy(result, key)
  if not dynamic or dynamic.mode ~= 'rgb' then
    return false, 'No RGB dynamic field is active'
  end

  dynamic.palette = dynamic_model.normalize_palette(dynamic.palette)
  local index = selected_palette_index(instance, dynamic)
  table.insert(dynamic.palette, index + 1, dynamic.palette[index])
  instance.state.field_editor.palette_index = index + 1
  local ok, err = apply_dynamic(instance, result, key, dynamic)
  if ok then
    jump_to_palette_index(instance, index + 1)
  end
  return ok, err
end

function M.delete_dynamic_palette_color(instance)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end
  local dynamic = current_dynamic_copy(result, key)
  if not dynamic or dynamic.mode ~= 'rgb' then
    return false, 'No RGB dynamic field is active'
  end

  dynamic.palette = dynamic_model.normalize_palette(dynamic.palette)
  if #dynamic.palette <= ui_fields.dynamic_palette_min_size then
    return false, 'Palette must keep at least two colors'
  end
  local index = selected_palette_index(instance, dynamic)
  table.remove(dynamic.palette, index)
  instance.state.field_editor.palette_index = math.min(index, #dynamic.palette)
  local ok, err = apply_dynamic(instance, result, key, dynamic)
  if ok then
    jump_to_palette_index(instance, instance.state.field_editor.palette_index)
  end
  return ok, err
end

function M.set_dynamic_palette_color(instance, value)
  local key = current_field(instance)
  local result = current_result(instance)
  if not result or not color_keys[key] then
    return false, 'No color field is active'
  end
  local dynamic = current_dynamic_copy(result, key)
  if not dynamic or dynamic.mode ~= 'rgb' then
    return false, 'No RGB dynamic field is active'
  end

  local normalized, err = color.normalize(value)
  if err or normalized == nil or normalized == 'NONE' then
    return false, err or 'Palette color must be a real color'
  end
  dynamic.palette = dynamic_model.normalize_palette(dynamic.palette)
  local index = selected_palette_index(instance, dynamic)
  dynamic.palette[index] = normalized
  local ok, apply_err = apply_dynamic(instance, result, key, dynamic)
  if ok then
    jump_to_palette_index(instance, index)
  end
  return ok, apply_err
end

function M.set_group(instance, group_name)
  local result = current_result(instance)
  if not result then
    return false, 'No detail result is active'
  end

  return apply_patch(instance, result, { group = group_name }, current_field(instance))
end

function M.set_blend(instance, value)
  local result = current_result(instance)
  if not result then
    return false, 'No detail result is active'
  end

  local normalized = nil
  if value ~= nil and vim.trim(tostring(value)) ~= '' then
    local number_value = tonumber(value)
    if number_value == nil or number_value < 0 or number_value > 100 then
      local err = 'Blend must be a number between 0 and 100'
      notify_error(err)
      return false, err
    end
    normalized = math.floor(number_value)
  end

  return apply_patch(instance, result, { blend = normalized == nil and vim.NIL or normalized }, current_field(instance))
end

function M.adjust_blend(instance, delta)
  local result = current_result(instance)
  if not result then
    return false, 'No detail result is active'
  end

  local runtime_value = session.draft_entry(result.name).blend
  local current = tonumber(runtime_value ~= nil and runtime_value or result.blend) or 0
  return M.set_blend(instance, clamp(current + (tonumber(delta) or 0), 0, 100))
end

return M
