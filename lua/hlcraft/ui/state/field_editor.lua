local color = require('hlcraft.color')
local detail_values = require('hlcraft.ui.state.detail_values')
local results_state = require('hlcraft.ui.state.results')
local ui_fields = require('hlcraft.ui.fields')
local workspace = require('hlcraft.ui.workspace')

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

local function menu_row_at_cursor(instance)
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
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
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
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

local function apply_patch(instance, result, patch, preserve_field)
  local ok, err = detail_values.apply_runtime(instance, result.name, patch)
  if not ok then
    notify_error(err or 'Failed to update highlight override')
    return false, err
  end

  if preserve_field then
    instance.state.field_editor.field = preserve_field
  end
  return true, nil
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

  local runtime_value = detail_values.runtime_entry(result.name)[row.key]
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

  local shift = channel_shifts[tostring(channel or ''):lower()]
  if not shift then
    return false, ('Unsupported color channel: %s'):format(tostring(channel))
  end

  local current = detail_values.runtime_entry(result.name)[key]
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

  local runtime_value = detail_values.runtime_entry(result.name).blend
  local current = tonumber(runtime_value ~= nil and runtime_value or result.blend) or 0
  return M.set_blend(instance, clamp(current + (tonumber(delta) or 0), 0, 100))
end

return M
