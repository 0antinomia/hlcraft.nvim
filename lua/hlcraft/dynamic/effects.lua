local color = require('hlcraft.color')
local model = require('hlcraft.dynamic.model')

local M = {}

local function clamp_channel(value)
  value = math.floor(value + 0.5)
  if value < 0 then
    return 0
  end
  if value > 255 then
    return 255
  end
  return value
end

local function rgb_to_hex(r, g, b)
  return ('#%02x%02x%02x'):format(clamp_channel(r), clamp_channel(g), clamp_channel(b))
end

function M.rgb(now_ms, speed)
  speed = model.normalize_speed(speed)
  local phase = (tonumber(now_ms) or 0) % speed
  local sector = phase / speed * 3

  if sector < 1 then
    return rgb_to_hex(255 * (1 - sector), 255 * sector, 0)
  elseif sector < 2 then
    local offset = sector - 1
    return rgb_to_hex(0, 255 * (1 - offset), 255 * offset)
  end

  local offset = sector - 2
  return rgb_to_hex(255 * offset, 0, 255 * (1 - offset))
end

function M.breath(base_hex, now_ms, speed)
  local base = color.hex_to_int(base_hex)
  if not base then
    return nil
  end

  speed = model.normalize_speed(speed)
  local phase = ((tonumber(now_ms) or 0) % speed) / speed
  local amount = 0.45 + (0.55 * ((math.sin((phase * 2 * math.pi) - (math.pi / 2)) + 1) / 2))
  local r, g, b = color.int_to_rgb(base)

  return rgb_to_hex(r * amount, g * amount, b * amount)
end

function M.compute(spec, base_hex, now_ms)
  local normalized = model.normalize_channel(spec)
  if not normalized then
    return nil
  end

  if normalized.mode == 'rgb' then
    return M.rgb(now_ms, normalized.speed)
  elseif normalized.mode == 'breath' then
    return M.breath(base_hex, now_ms, normalized.speed)
  end

  return nil
end

return M
