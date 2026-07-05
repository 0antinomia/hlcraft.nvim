local M = {}

--- Return true when value is a finite Lua number.
--- @param value any
--- @return boolean
function M.is_finite(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function finite_fallback(fallback, default, level)
  if fallback == nil then
    return default
  end
  if not M.is_finite(fallback) then
    error('number fallback must be finite', level)
  end
  return fallback
end

--- Convert a value to a finite number, or return fallback.
--- @param value any
--- @param fallback number|nil
--- @return number|nil
function M.to_finite(value, fallback)
  fallback = finite_fallback(fallback, nil, 2)
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
  if not M.is_finite(value) then
    error('clamp value must be finite', 2)
  end
  if not M.is_finite(min) then
    error('clamp min must be finite', 2)
  end
  if not M.is_finite(max) then
    error('clamp max must be finite', 2)
  end
  if min > max then
    error('clamp min must not exceed max', 2)
  end

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
  return M.clamp(M.to_finite(value, finite_fallback(fallback, 0, 2)), min, max)
end

--- Clamp a value to the 0..1 range.
--- @param value any
--- @param fallback number|nil
--- @return number
function M.unit(value, fallback)
  return M.clamp_finite(value, 0, 1, fallback)
end

return M
