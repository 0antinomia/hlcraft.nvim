local color = require('hlcraft.core.color')
local numbers = require('hlcraft.core.number')
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

local function fallback_color(result, key)
  if key == 'fg' then
    return result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  end
  if key == 'bg' then
    return result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  end
  return result[key]
end

function M.set(instance, result, key, value)
  local normalized, err = color.normalize(value)
  if err then
    return false, err
  end
  return session.set_color(instance, result.name, key, normalized)
end

function M.adjust(instance, result, key, channel, delta)
  local shift = channel_shifts[tostring(channel or ''):lower()]
  if not shift then
    return false, ('Unsupported color channel: %s'):format(tostring(channel))
  end
  local current = session.field_value(result.name, key)
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
  local amount = numbers.to_finite(delta, 0)
  local component = math.floor(rgb / (2 ^ shift)) % 256
  local adjusted = numbers.clamp(component + amount, 0, 255)
  local next_rgb = rgb + ((adjusted - component) * (2 ^ shift))
  return M.set(instance, result, key, color.int_to_hex(next_rgb))
end

return M
