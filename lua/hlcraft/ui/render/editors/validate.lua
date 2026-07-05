local dynamic_model = require('hlcraft.dynamic.model')
local numbers = require('hlcraft.core.number')

local M = {}

function M.instance(instance, label)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error(('%s requires an instance'):format(label), 3)
  end
  return instance
end

function M.geometry(geometry, label)
  if type(geometry) ~= 'table' or type(geometry.editor_rows) ~= 'table' then
    error(('%s requires editor geometry'):format(label), 3)
  end
  return geometry
end

function M.result(result, label)
  if type(result) ~= 'table' or type(result.name) ~= 'string' or result.name == '' then
    error(('%s requires a highlight result'):format(label), 3)
  end
  return result
end

function M.field(field, label)
  if type(field) ~= 'string' or field == '' then
    error(('%s requires a field'):format(label), 3)
  end
  return field
end

function M.width(width, label)
  if type(width) ~= 'number' then
    error(('%s width must be a number'):format(label), 3)
  end
  if not numbers.is_finite(width) or math.floor(width) ~= width or width < 1 then
    error(('%s width must be a positive finite integer'):format(label), 3)
  end
  return width
end

function M.dynamic(dynamic, label)
  dynamic = dynamic_model.normalize_channel(dynamic)
  if not dynamic then
    error(('%s requires a dynamic color'):format(label), 3)
  end
  return dynamic
end

return M
