local M = {}

--- Return true when value is a finite Lua number.
--- @param value any
--- @return boolean
function M.is_finite(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

--- Convert a value to a finite number, or return fallback.
--- @param value any
--- @param fallback number|nil
--- @return number|nil
function M.to_finite(value, fallback)
  local number = tonumber(value)
  if M.is_finite(number) then
    return number
  end
  return fallback
end

--- Clamp a known finite number between min and max.
--- @param value number
--- @param min number
--- @param max number
--- @return number
function M.clamp(value, min, max)
  if value < min then
    return min
  end
  if value > max then
    return max
  end
  return value
end

--- Convert a value to a finite number and clamp it.
--- @param value any
--- @param min number
--- @param max number
--- @param fallback number|nil
--- @return number
function M.clamp_finite(value, min, max, fallback)
  return M.clamp(M.to_finite(value, fallback or 0), min, max)
end

--- Clamp a value to the 0..1 range.
--- @param value any
--- @param fallback number|nil
--- @return number
function M.unit(value, fallback)
  return M.clamp_finite(value, 0, 1, fallback or 0)
end

return M
