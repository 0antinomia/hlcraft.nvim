local numbers = require('hlcraft.core.number')
local context = require('hlcraft.ui.editor.context')
local session = require('hlcraft.ui.session')

local M = {}

local blend_error = 'Blend must be a number between 0 and 100'

local function normalize_blend(value)
  if value == nil then
    return nil, nil
  end

  if type(value) == 'string' then
    value = vim.trim(value)
    if value == '' then
      return nil, nil
    end
  elseif type(value) ~= 'number' then
    return nil, blend_error
  end

  local number_value = numbers.to_finite(value, nil)
  if number_value == nil or number_value < 0 or number_value > 100 then
    return nil, blend_error
  end

  return math.floor(number_value), nil
end

function M.set(instance, result, value)
  local name = context.result_name(result, 'blend editor')
  local normalized, err = normalize_blend(value)
  if err then
    return false, err
  end
  return session.set_blend(instance, name, normalized)
end

function M.adjust(instance, result, delta)
  local name = context.result_name(result, 'blend editor')
  if not numbers.is_finite(delta) then
    return false, 'Blend adjustment delta must be a finite number'
  end

  local draft_value = session.field_value(name, 'blend')
  local current = draft_value ~= nil and draft_value or result.blend
  if current == nil then
    current = 0
  elseif not numbers.is_finite(current) then
    return false, 'Current blend must be a finite number'
  end

  return M.set(instance, result, numbers.clamp(current + delta, 0, 100))
end

return M
