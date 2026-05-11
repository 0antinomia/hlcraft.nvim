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

local function interpolate_channel(left, right, amount)
  return left + ((right - left) * amount)
end

local function interpolate_hex(left_hex, right_hex, amount)
  local left = color.hex_to_int(left_hex)
  local right = color.hex_to_int(right_hex)
  if not left or not right then
    return nil
  end

  local lr, lg, lb = color.int_to_rgb(left)
  local rr, rg, rb = color.int_to_rgb(right)
  return rgb_to_hex(
    interpolate_channel(lr, rr, amount),
    interpolate_channel(lg, rg, amount),
    interpolate_channel(lb, rb, amount)
  )
end

function M.rgb(now_ms, speed, palette)
  speed = model.normalize_speed(speed)
  local normalized_palette = model.normalize_palette(palette)
  local phase = ((tonumber(now_ms) or 0) % speed) / speed
  local scaled = phase * #normalized_palette
  local left_index = math.floor(scaled) + 1
  local right_index = (left_index % #normalized_palette) + 1
  local amount = scaled - math.floor(scaled)

  return interpolate_hex(normalized_palette[left_index], normalized_palette[right_index], amount)
end

function M.breath(base_hex, now_ms, speed, params)
  local base = color.hex_to_int(base_hex)
  if not base then
    return nil
  end

  speed = model.normalize_speed(speed)
  local normalized_params = model.normalize_params('breath', params)
  local phase = ((tonumber(now_ms) or 0) % speed) / speed
  local curve = (math.sin((phase * 2 * math.pi) - (math.pi / 2)) + 1) / 2
  local amount = normalized_params.min + ((normalized_params.max - normalized_params.min) * curve)
  local r, g, b = color.int_to_rgb(base)

  return rgb_to_hex(r * amount, g * amount, b * amount)
end

function M.compute(spec, base_hex, now_ms)
  local normalized = model.normalize_channel(spec)
  if not normalized then
    return nil
  end

  if normalized.mode == 'rgb' then
    return M.rgb(now_ms, normalized.speed, normalized.palette)
  elseif normalized.mode == 'breath' then
    return M.breath(base_hex, now_ms, normalized.speed, normalized.params)
  end

  return nil
end

return M
