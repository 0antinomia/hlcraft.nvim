--- @type table
local M = {}

--- Convert a 24-bit RGB integer to #RRGGBB hex string
--- @param n integer|nil Color value from nvim_get_hl
--- @return string hex color as "#RRGGBB" or "NONE"
function M.int_to_hex(n)
  if not n then
    return 'NONE'
  end
  return ('#%06x'):format(n)
end

--- Convert a #RRGGBB hex string to 24-bit RGB integer
--- @param s string|nil Hex color string (with or without #)
--- @return integer|nil 24-bit RGB value, or nil if invalid
function M.hex_to_int(s)
  if not s then
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
  if not name then
    return nil
  end
  local result = vim.api.nvim_get_color_by_name(name)
  if result == -1 then
    return nil
  end
  return result
end

--- Normalize user color input into hlcraft's persisted representation.
--- @param value string|nil User-provided color string
--- @return string|nil normalized Normalized value as "#rrggbb" or "NONE"
--- @return string|nil err Validation error for invalid input
function M.normalize(value)
  if value == nil then
    return nil, nil
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
  local r = math.floor(n / 65536) % 256
  local g = math.floor(n / 256) % 256
  local b = n % 256
  return r, g, b
end

--- Calculate a contrasting foreground color (light or dark) for readability on a given background.
--- Uses ITU-R BT.601 luminance weights with threshold 186.
--- @param hex string|nil Background color in #RRGGBB format
--- @return string Foreground color as #RRGGBB
function M.contrast_fg(hex)
  if not hex or hex == 'NONE' then
    return '#808080'
  end
  local value = tonumber(hex:gsub('^#', ''), 16)
  if not value then
    return '#808080'
  end
  local r, g, b = M.int_to_rgb(value)
  local luminance = (0.299 * r) + (0.587 * g) + (0.114 * b)
  return luminance > 186 and '#1f2335' or '#e9e9ec'
end

return M
