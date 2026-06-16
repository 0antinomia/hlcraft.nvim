local session = require('hlcraft.ui.session')

local M = {}

local function clamp(value, min, max)
  return math.max(min, math.min(max, value))
end

function M.set(instance, result, value)
  local normalized = nil
  if value ~= nil and vim.trim(tostring(value)) ~= '' then
    local number_value = tonumber(value)
    if number_value == nil or number_value < 0 or number_value > 100 then
      return false, 'Blend must be a number between 0 and 100'
    end
    normalized = math.floor(number_value)
  end
  return session.set_blend(instance, result.name, normalized)
end

function M.adjust(instance, result, delta)
  local runtime_value = session.field_value(result.name, 'blend')
  local current = tonumber(runtime_value ~= nil and runtime_value or result.blend) or 0
  return M.set(instance, result, clamp(current + (tonumber(delta) or 0), 0, 100))
end

return M
