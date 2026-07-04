local numbers = require('hlcraft.core.number')
local session = require('hlcraft.ui.session')

local M = {}

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
  local draft_value = session.field_value(result.name, 'blend')
  local current = numbers.to_finite(draft_value ~= nil and draft_value or result.blend, 0)
  return M.set(instance, result, numbers.clamp(current + numbers.to_finite(delta, 0), 0, 100))
end

return M
