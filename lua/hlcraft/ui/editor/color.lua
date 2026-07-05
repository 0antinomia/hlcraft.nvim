local color = require('hlcraft.core.color')
local numbers = require('hlcraft.core.number')
local context = require('hlcraft.ui.editor.context')
local field_values = require('hlcraft.ui.field_values')
local session = require('hlcraft.ui.session')

local M = {}

local channel_shifts = {
  r = 16,
  red = 16,
  g = 8,
  green = 8,
  b = 0,
  blue = 0,
}

function M.set(instance, result, key, value)
  local name = context.result_name(result, 'color editor')
  key = context.field_key(key, 'color editor')
  local normalized, err = color.normalize(value)
  if err then
    return false, err
  end
  return session.set_color(instance, name, key, normalized)
end

function M.adjust(instance, result, key, channel, delta)
  local name = context.result_name(result, 'color editor')
  key = context.field_key(key, 'color editor')
  if type(channel) ~= 'string' then
    return false, 'Color channel must be a string'
  end
  if not numbers.is_finite(delta) then
    return false, 'Color adjustment delta must be a finite number'
  end

  local shift = channel_shifts[channel:lower()]
  if not shift then
    return false, ('Unsupported color channel: %s'):format(channel)
  end
  local current = session.field_value(name, key)
  if current == nil then
    current = field_values.fallback_value(result, key)
  end
  if current == nil or current == 'NONE' then
    current = '#000000'
  end
  local rgb = color.hex_to_int(current)
  if not rgb then
    return false, ('Cannot adjust invalid color: %s'):format(tostring(current))
  end
  local component = math.floor(rgb / (2 ^ shift)) % 256
  local adjusted = numbers.clamp(component + delta, 0, 255)
  local next_rgb = rgb + ((adjusted - component) * (2 ^ shift))
  return M.set(instance, result, key, color.int_to_hex(next_rgb))
end

return M
