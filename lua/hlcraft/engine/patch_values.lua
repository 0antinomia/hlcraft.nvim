local color = require('hlcraft.core.color')
local dynamic_model = require('hlcraft.dynamic.model')

local M = {}

function M.is_unset(value)
  return value == nil or value == vim.NIL or (type(value) == 'string' and vim.trim(value) == '')
end

function M.entry_value(value)
  if value == vim.NIL then
    return nil
  end
  return value
end

function M.normalize_blend(value)
  if M.is_unset(value) then
    return vim.NIL, nil
  end

  local number_value = tonumber(value)
  if number_value == nil then
    return nil, 'Blend override must be a number or empty'
  end

  if number_value < 0 or number_value > 100 then
    return nil, 'Blend override must be between 0 and 100'
  end

  return math.floor(number_value), nil
end

function M.normalize_color(value)
  if M.is_unset(value) then
    return vim.NIL, nil
  end

  local normalized, err = color.normalize(value)
  if err then
    return nil, err
  end
  return normalized, nil
end

function M.normalize_style(key, value)
  if value == vim.NIL then
    return vim.NIL, nil
  end

  if value ~= nil and type(value) ~= 'boolean' then
    return nil, ('Style override %s must be boolean or nil'):format(key)
  end

  return value == nil and vim.NIL or value, nil
end

function M.normalize_dynamic_channel(key, value)
  if M.is_unset(value) then
    return vim.NIL, nil
  end

  local normalized = dynamic_model.normalize_channel(value)
  if not normalized then
    return nil, ('Invalid dynamic spec for %s'):format(key)
  end

  return normalized, nil
end

return M
