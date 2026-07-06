--- @type table
local M = {}

local numbers = require('hlcraft.core.number')

local function rgb_integer(value, label)
  if not numbers.is_integer(value, 0) or value > 0xffffff then
    error(('%s must be a 24-bit RGB integer'):format(label), 3)
  end
  return value
end

--- Convert a 24-bit RGB integer to #RRGGBB hex string
--- @param n integer|nil Color value from nvim_get_hl
--- @return string hex color as "#RRGGBB" or "NONE"
function M.int_to_hex(n)
  if not numbers.is_integer(n, 0) or n > 0xffffff then
    return 'NONE'
  end
  return ('#%06x'):format(n)
end

--- Convert a #RRGGBB hex string to 24-bit RGB integer
--- @param s string|nil Hex color string (with or without #)
--- @return integer|nil 24-bit RGB value, or nil if invalid
function M.hex_to_int(s)
  if type(s) ~= 'string' then
    return nil
  end
  s = s:gsub('^#', '')
  if #s ~= 6 then
    return nil
  end
  return tonumber(s, 16)
end

--- Convert a color name or hex string to RGB integer
--- @param name string|nil Color name ("red") or hex ("#ff0000")
--- @return integer|nil 24-bit RGB value, or nil if invalid
function M.name_to_int(name)
  if type(name) ~= 'string' then
    return nil
  end
  local result = vim.api.nvim_get_color_by_name(name)
  if result == -1 then
    return nil
  end
  return result
end

--- Normalize user color input into hlcraft's persisted representation.
--- @param value any User-provided color string
--- @return string|nil normalized Normalized value as "#rrggbb" or "NONE"
--- @return string|nil err Validation error for invalid input
function M.normalize(value)
  if value == nil then
    return nil, nil
  end

  if type(value) ~= 'string' then
    return nil, ('Color must be a string or nil, got %s'):format(type(value))
  end

  local text = vim.trim(value)
  if text == '' then
    return nil, nil
  end

  if text:upper() == 'NONE' then
    return 'NONE', nil
  end

  local hex_value = M.hex_to_int(text)
  if hex_value then
    return M.int_to_hex(hex_value), nil
  end

  local named_value = M.name_to_int(text)
  if named_value then
    return M.int_to_hex(named_value), nil
  end

  return nil, ('Invalid color: %s. Use #RRGGBB, color name, or NONE.'):format(text)
end

--- Extract R, G, B components from a 24-bit integer
--- @param n integer 24-bit RGB integer
--- @return integer r
--- @return integer g
--- @return integer b
function M.int_to_rgb(n)
  n = rgb_integer(n, 'RGB color')
  local r = math.floor(n / 65536) % 256
  local g = math.floor(n / 256) % 256
  local b = n % 256
  return r, g, b
end

--- Round and clamp a numeric RGB channel into 0..255.
--- @param value number Channel value
--- @return integer channel Clamped channel
function M.clamp_channel(value)
  if not numbers.is_finite(value) then
    error('RGB channel must be finite', 2)
  end
  local channel = math.floor(value + 0.5)
  return numbers.clamp(channel, 0, 255)
end

--- Convert RGB channels to a normalized #RRGGBB hex string.
--- @param r number Red channel
--- @param g number Green channel
--- @param b number Blue channel
--- @return string hex Hex color
function M.rgb_to_hex(r, g, b)
  return ('#%02x%02x%02x'):format(M.clamp_channel(r), M.clamp_channel(g), M.clamp_channel(b))
end

--- Calculate a contrasting foreground color (light or dark) for readability on a given background.
--- Uses ITU-R BT.601 luminance weights with threshold 186.
--- @param hex string|nil Background color in #RRGGBB format
--- @return string Foreground color as #RRGGBB
function M.contrast_fg(hex)
  if hex == 'NONE' then
    return '#808080'
  end
  local value = M.hex_to_int(hex)
  if not value then
    return '#808080'
  end
  local r, g, b = M.int_to_rgb(value)
  local luminance = (0.299 * r) + (0.587 * g) + (0.114 * b)
  return luminance > 186 and '#1f2335' or '#e9e9ec'
end

return M
