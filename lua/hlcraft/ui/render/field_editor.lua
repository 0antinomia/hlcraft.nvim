local dynamic_model = require('hlcraft.dynamic.model')
local session = require('hlcraft.ui.session')
local color_renderer = require('hlcraft.ui.render.editors.color')
local dynamic_renderer = require('hlcraft.ui.render.editors.dynamic')
local group_renderer = require('hlcraft.ui.render.editors.group')
local blend_renderer = require('hlcraft.ui.render.editors.blend')

local M = {}

local function normalize_build_args(instance, geometry, result, field, width, line_offset)
  if line_offset ~= nil or width ~= nil then
    return instance, geometry, result, field, width, line_offset or 0
  end

  return nil, instance, geometry, result, field, 0
end

function M.build(instance, geometry, result, field, width, line_offset)
  instance, geometry, result, field, width, line_offset =
    normalize_build_args(instance, geometry, result, field, width, line_offset)
  if field == 'fg' or field == 'bg' or field == 'sp' then
    local dynamic = dynamic_model.channel_set[field] and session.dynamic_value(result.name, field) or nil
    if dynamic then
      return dynamic_renderer.build(instance, geometry, result, field, width, line_offset, dynamic)
    end
    return color_renderer.build(instance, geometry, result, field, width, line_offset)
  end
  if field == 'group' then
    return group_renderer.build(geometry, result, width)
  end
  if field == 'blend' then
    return blend_renderer.build(geometry, result, width)
  end
  return nil
end

return M
