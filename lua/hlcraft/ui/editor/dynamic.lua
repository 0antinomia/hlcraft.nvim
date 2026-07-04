local dynamic_model = require('hlcraft.dynamic.model')
local json = require('hlcraft.ui.json')
local numbers = require('hlcraft.core.number')
local constants = require('hlcraft.dynamic.constants')
local presets = require('hlcraft.dynamic.presets')
local session = require('hlcraft.ui.session')

local M = {}

local function copy_dynamic(result, key)
  local dynamic = session.dynamic_value(result.name, key)
  return dynamic and vim.deepcopy(dynamic) or nil
end

local function preset_index(names, name)
  for index, candidate in ipairs(names) do
    if candidate == name then
      return index
    end
  end
  return nil
end

local function normalize_for_set(spec)
  local normalized = dynamic_model.normalize_channel(spec)
  if not normalized then
    return nil, 'Invalid dynamic color JSON'
  end
  return normalized, nil
end

local function set_normalized(instance, result, key, spec)
  local normalized, err = normalize_for_set(spec)
  if not normalized then
    return false, err
  end
  return session.set_dynamic(instance, result.name, key, normalized)
end

function M.toggle(instance, result, key)
  local next_value = session.dynamic_value(result.name, key) and nil or presets.default()
  return session.set_dynamic(instance, result.name, key, next_value)
end

function M.cycle_preset(instance, result, key)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  local preset_names = presets.names()
  local current = preset_index(preset_names, dynamic.preset) or 0
  local next_name = preset_names[current + 1] or preset_names[1]
  return set_normalized(instance, result, key, presets.get(next_name))
end

function M.adjust_duration(instance, result, key, delta)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  dynamic.duration =
    dynamic_model.normalize_duration((dynamic.duration or dynamic_model.default_duration) + numbers.to_finite(delta, 0))
  return set_normalized(instance, result, key, dynamic)
end

function M.set_loop(instance, result, key, value)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  if not constants.loop_set[value] then
    return false, ('Loop must be one of: %s'):format(table.concat(constants.loops, ', '))
  end
  dynamic.loop = value
  return set_normalized(instance, result, key, dynamic)
end

function M.set_phase(instance, result, key, value)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  local phase = numbers.to_finite(value, nil)
  if phase == nil then
    return false, 'Phase must be a number'
  end
  dynamic.phase = numbers.unit(phase, 0)
  return set_normalized(instance, result, key, dynamic)
end

function M.set_raw_json(instance, result, key, text)
  local decoded = json.decode_object(text)
  if not decoded then
    return false, 'Dynamic JSON must be a JSON object'
  end

  return set_normalized(instance, result, key, decoded)
end

return M
