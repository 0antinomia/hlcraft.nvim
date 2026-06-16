local color = require('hlcraft.core.color')
local dynamic_model = require('hlcraft.dynamic.model')
local session = require('hlcraft.ui.session')
local ui_fields = require('hlcraft.ui.fields')

local M = {}

local function next_mode(mode)
  local modes = ui_fields.dynamic_modes
  for index, candidate in ipairs(modes) do
    if candidate == mode then
      return modes[index + 1] or modes[1]
    end
  end
  return modes[1]
end

local function copy_dynamic(result, key)
  local dynamic = session.dynamic_value(result.name, key)
  return dynamic and vim.deepcopy(dynamic) or nil
end

local function is_finite_number(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function normalize_palette_index(palette, index)
  local count = #palette
  if count == 0 then
    return 1
  end
  return math.max(1, math.min(count, tonumber(index) or 1))
end

function M.toggle(instance, result, key)
  local next_value = session.dynamic_value(result.name, key) and nil or dynamic_model.default_spec()
  return session.set_dynamic(instance, result.name, key, next_value)
end

function M.cycle_mode(instance, result, key)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end
  dynamic.mode = next_mode(dynamic.mode)
  return session.set_dynamic(instance, result.name, key, dynamic)
end

function M.adjust_speed(instance, result, key, delta)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end
  dynamic.speed = dynamic_model.normalize_speed(dynamic.speed + (tonumber(delta) or 0))
  return session.set_dynamic(instance, result.name, key, dynamic)
end

function M.set_param(instance, result, key, name, value)
  local dynamic = copy_dynamic(result, key)
  if not dynamic or dynamic.mode ~= 'breath' then
    return false, 'No breath dynamic field is active'
  end
  if name ~= 'min' and name ~= 'max' then
    return false, ('Unsupported dynamic param: %s'):format(tostring(name))
  end
  local number_value = tonumber(value)
  if not is_finite_number(number_value) then
    return false, 'Breath dynamic param must be a number'
  end
  dynamic.params = dynamic_model.normalize_params('breath', dynamic.params)
  dynamic.params[name] = number_value
  dynamic.params = dynamic_model.normalize_params('breath', dynamic.params)
  return session.set_dynamic(instance, result.name, key, dynamic)
end

function M.adjust_param(instance, result, key, name, delta)
  local dynamic = copy_dynamic(result, key)
  if not dynamic or dynamic.mode ~= 'breath' then
    return false, 'No breath dynamic field is active'
  end
  if name ~= 'min' and name ~= 'max' then
    return false, ('Unsupported dynamic param: %s'):format(tostring(name))
  end
  local params = dynamic_model.normalize_params('breath', dynamic.params)
  return M.set_param(instance, result, key, name, params[name] + (tonumber(delta) or 0))
end

function M.select_palette(instance, result, key, current_index, delta)
  local dynamic = copy_dynamic(result, key)
  if not dynamic or dynamic.mode ~= 'rgb' then
    return false, 'No RGB dynamic field is active'
  end
  local palette = dynamic_model.normalize_palette(dynamic.palette)
  local count = #palette
  local current = normalize_palette_index(palette, current_index)
  local next_index = ((current - 1 + (tonumber(delta) or 0)) % count) + 1
  return true, next_index
end

function M.add_palette_color(instance, result, key, index)
  local dynamic = copy_dynamic(result, key)
  if not dynamic or dynamic.mode ~= 'rgb' then
    return false, 'No RGB dynamic field is active'
  end
  dynamic.palette = dynamic_model.normalize_palette(dynamic.palette)
  local insert_at = normalize_palette_index(dynamic.palette, index)
  table.insert(dynamic.palette, insert_at + 1, dynamic.palette[insert_at])
  local next_index = insert_at + 1
  local ok, err = session.set_dynamic(instance, result.name, key, dynamic)
  return ok, err, next_index
end

function M.delete_palette_color(instance, result, key, index)
  local dynamic = copy_dynamic(result, key)
  if not dynamic or dynamic.mode ~= 'rgb' then
    return false, 'No RGB dynamic field is active'
  end
  dynamic.palette = dynamic_model.normalize_palette(dynamic.palette)
  if #dynamic.palette <= ui_fields.dynamic_palette_min_size then
    return false, 'Palette must keep at least two colors'
  end
  local delete_at = normalize_palette_index(dynamic.palette, index)
  table.remove(dynamic.palette, delete_at)
  local next_index = math.min(delete_at, #dynamic.palette)
  local ok, err = session.set_dynamic(instance, result.name, key, dynamic)
  return ok, err, next_index
end

function M.set_palette_color(instance, result, key, index, value)
  local dynamic = copy_dynamic(result, key)
  if not dynamic or dynamic.mode ~= 'rgb' then
    return false, 'No RGB dynamic field is active'
  end
  local normalized, err = color.normalize(value)
  if err or normalized == nil or normalized == 'NONE' then
    return false, err or 'Palette color must be a real color'
  end
  dynamic.palette = dynamic_model.normalize_palette(dynamic.palette)
  local palette_index = normalize_palette_index(dynamic.palette, index)
  dynamic.palette[palette_index] = normalized
  local ok, apply_err = session.set_dynamic(instance, result.name, key, dynamic)
  return ok, apply_err, palette_index
end

return M
