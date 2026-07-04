local color = require('hlcraft.core.color')
local numbers = require('hlcraft.core.number')

local M = {}

local function hue_to_rgb(p, q, t)
  if t < 0 then
    t = t + 1
  end
  if t > 1 then
    t = t - 1
  end
  if t < 1 / 6 then
    return p + ((q - p) * 6 * t)
  end
  if t < 1 / 2 then
    return q
  end
  if t < 2 / 3 then
    return p + ((q - p) * ((2 / 3) - t) * 6)
  end
  return p
end

local function rgb_to_hsl(r, g, b)
  r = r / 255
  g = g / 255
  b = b / 255

  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local h = 0
  local s = 0
  local l = (max + min) / 2

  if max ~= min then
    local d = max - min
    s = l > 0.5 and d / (2 - max - min) or d / (max + min)
    if max == r then
      h = ((g - b) / d) + (g < b and 6 or 0)
    elseif max == g then
      h = ((b - r) / d) + 2
    else
      h = ((r - g) / d) + 4
    end
    h = h / 6
  end

  return h, s, l
end

local function hsl_to_rgb(h, s, l)
  h = h % 1
  s = numbers.clamp(s, 0, 1)
  l = numbers.clamp(l, 0, 1)

  if s == 0 then
    local gray = l * 255
    return gray, gray, gray
  end

  local q = l < 0.5 and l * (1 + s) or l + s - (l * s)
  local p = (2 * l) - q
  return hue_to_rgb(p, q, h + (1 / 3)) * 255, hue_to_rgb(p, q, h) * 255, hue_to_rgb(p, q, h - (1 / 3)) * 255
end

function M.apply(hex, transform)
  local value = color.hex_to_int(hex)
  if not value or type(transform) ~= 'table' then
    return nil
  end

  local amount = numbers.to_finite(transform.value, nil)
  if not amount then
    return hex
  end

  local r, g, b = color.int_to_rgb(value)
  if transform.type == 'brightness' then
    amount = numbers.clamp(amount, 0, 2)
    return color.rgb_to_hex(r * amount, g * amount, b * amount)
  end

  local h, s, l = rgb_to_hsl(r, g, b)
  if transform.type == 'hue_shift' then
    h = h + (amount / 360)
  elseif transform.type == 'saturation' then
    amount = numbers.clamp(amount, 0, 2)
    s = s * amount
  else
    return hex
  end

  return color.rgb_to_hex(hsl_to_rgb(h, s, l))
end

return M
