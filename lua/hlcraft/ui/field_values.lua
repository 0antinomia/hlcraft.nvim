local fields = require('hlcraft.core.fields')
local numbers = require('hlcraft.core.number')

local M = {}

local fallback_keys = vim.tbl_extend('force', { group = true }, fields.override_set)

local function assert_result(result)
  if type(result) ~= 'table' then
    error('field fallback result must be a table', 3)
  end
  return result
end

local function assert_key(key)
  if type(key) ~= 'string' then
    error('field fallback key must be a string', 3)
  end
  if not fallback_keys[key] then
    error(('unsupported field fallback key: %s'):format(key), 3)
  end
  return key
end

function M.fallback_value(result, key)
  result = assert_result(result)
  key = assert_key(key)
  if key == 'fg' then
    return result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  end
  if key == 'bg' then
    return result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  end
  if key == 'sp' then
    return result.sp
  end
  return result[key]
end

function M.display_text(value)
  if value == nil then
    return 'unset'
  end
  if value == true then
    return 'true'
  end
  if value == false then
    return 'false'
  end
  if type(value) == 'string' then
    return value
  end
  if type(value) == 'number' then
    if not numbers.is_finite(value) then
      error('display value number must be finite', 2)
    end
    return tostring(value)
  end
  error(('display value must be nil, boolean, string, or finite number, got %s'):format(type(value)), 2)
end

return M
