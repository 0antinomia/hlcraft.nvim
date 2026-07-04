local dynamic_model = require('hlcraft.dynamic.model')
local presets = require('hlcraft.dynamic.presets')
local session = require('hlcraft.ui.session')

local M = {}

local function copy_dynamic(result, key)
  local dynamic = session.dynamic_value(result.name, key)
  return dynamic and vim.deepcopy(dynamic) or nil
end

local function preset_index(name)
  for index, candidate in ipairs(dynamic_model.presets) do
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
  local next_value = session.dynamic_value(result.name, key) and nil or presets.get('pulse')
  return session.set_dynamic(instance, result.name, key, next_value)
end

function M.cycle_preset(instance, result, key)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  local current = preset_index(dynamic.preset) or 0
  local next_name = dynamic_model.presets[current + 1] or dynamic_model.presets[1]
  return set_normalized(instance, result, key, presets.get(next_name))
end

function M.adjust_duration(instance, result, key, delta)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  dynamic.duration =
    dynamic_model.normalize_duration((dynamic.duration or dynamic_model.default_duration) + (tonumber(delta) or 0))
  return set_normalized(instance, result, key, dynamic)
end

function M.set_loop(instance, result, key, value)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  dynamic.loop = dynamic_model.normalize_loop(value)
  return set_normalized(instance, result, key, dynamic)
end

function M.set_phase(instance, result, key, value)
  local dynamic = copy_dynamic(result, key)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  local phase = tonumber(value)
  if type(phase) ~= 'number' or phase ~= phase or phase == math.huge or phase == -math.huge then
    return false, 'Phase must be a number'
  end
  dynamic.phase = math.max(0, math.min(1, phase))
  return set_normalized(instance, result, key, dynamic)
end

function M.set_raw_json(instance, result, key, text)
  local ok, decoded = pcall(vim.json.decode, tostring(text or ''))
  if not ok or type(decoded) ~= 'table' then
    return false, 'Dynamic JSON must be a JSON object'
  end

  return set_normalized(instance, result, key, decoded)
end

return M
