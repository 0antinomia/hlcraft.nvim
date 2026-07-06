local dynamic_model = require('hlcraft.dynamic.model')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local field_values = require('hlcraft.ui.field_values')
local session = require('hlcraft.ui.session')

local M = {}

local function assert_result(result)
  if type(result) ~= 'table' or type(result.name) ~= 'string' or result.name == '' then
    error('dynamic display requires a highlight result', 3)
  end
  return result
end

local function assert_channel(key)
  if type(key) ~= 'string' or not dynamic_model.channel_set[key] then
    error(('dynamic display requires a color channel, got %s'):format(tostring(key)), 3)
  end
  return key
end

local function color_text(value)
  if value == nil then
    return 'NONE'
  end
  return field_values.display_text(value)
end

function M.metadata(dynamic)
  if type(dynamic) ~= 'table' then
    error('dynamic display metadata requires a dynamic spec', 2)
  end
  return ('%s %dms %s'):format(dynamic.preset or 'custom', dynamic.duration, dynamic.loop)
end

function M.dynamic_value(result, key)
  result = assert_result(result)
  key = assert_channel(key)
  return session.dynamic_value(result.name, key)
end

function M.base_value(result, key)
  result = assert_result(result)
  key = assert_channel(key)

  local explicit = session.field_value(result.name, key)
  if explicit ~= nil then
    return explicit
  end

  local base_spec = dynamic_runtime.base_spec(result.name)
  if type(base_spec) == 'table' and base_spec[key] ~= nil then
    return base_spec[key]
  end

  return field_values.fallback_value(result, key)
end

function M.base_text(result, key)
  return color_text(M.base_value(result, key))
end

function M.color_context(result)
  result = assert_result(result)
  local context = {}
  for _, key in ipairs(dynamic_model.channels) do
    context[key] = M.base_value(result, key)
  end
  return context
end

function M.list_cell(result, key)
  result = assert_result(result)
  key = assert_channel(key)
  local dynamic = M.dynamic_value(result, key)
  if dynamic then
    return {
      text = 'Dynamic',
      dynamic = dynamic,
    }
  end

  return {
    text = color_text(result[key]),
    color = result[key],
  }
end

function M.detail_text(result, key, swatch)
  result = assert_result(result)
  key = assert_channel(key)
  if type(swatch) ~= 'string' or swatch == '' then
    error('dynamic display detail swatch must be a non-empty string', 3)
  end

  local dynamic = M.dynamic_value(result, key)
  if not dynamic then
    local fallback = field_values.fallback_value(result, key)
    return session.display_value(result.name, key, fallback)
  end

  return ('%s live %s'):format(swatch, M.metadata(dynamic))
end

return M
