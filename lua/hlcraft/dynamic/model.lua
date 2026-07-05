local color = require('hlcraft.core.color')
local constants = require('hlcraft.dynamic.constants')
local fields = require('hlcraft.core.fields')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')

local M = {}

M.channels = vim.deepcopy(fields.color_keys)
M.channel_set = vim.deepcopy(fields.color_set)

M.version = constants.version
M.default_duration = constants.default_duration
M.default_interpolation = constants.default_interpolation
M.default_loop = constants.default_loop
M.default_phase = constants.default_phase
local color_refs = { base = true }
for _, key in ipairs(fields.color_keys) do
  color_refs[key] = true
end

local channel_keys = {
  version = true,
  preset = true,
  duration = true,
  loop = true,
  phase = true,
  interpolation = true,
  timeline = true,
  transforms = true,
}

local color_stop_keys = {
  at = true,
  color = true,
}

local transform_keys = {
  type = true,
  interpolation = true,
  timeline = true,
}

local value_stop_keys = {
  at = true,
  value = true,
}

local function normalize_at(value)
  if not numbers.is_finite(value) or value < 0 or value > 1 then
    return nil
  end
  return value
end

local function sort_stops(stops)
  table.sort(stops, function(left, right)
    return left.at < right.at
  end)
  return stops
end

local function normalize_stop_sequence(stops, normalize_stop)
  if not tables.is_sequence(stops) or next(stops) == nil then
    return nil
  end

  local normalized = {}
  for _, stop in ipairs(stops) do
    local normalized_stop = normalize_stop(stop)
    if not normalized_stop then
      return nil
    end
    normalized[#normalized + 1] = normalized_stop
  end

  return sort_stops(normalized)
end

function M.normalize_duration(value)
  if type(value) ~= 'number' or not numbers.is_finite(value) then
    error('Dynamic duration must be a finite number', 2)
  end

  local duration = math.floor(value)
  if duration < constants.min_duration then
    return constants.min_duration
  end
  if duration > constants.max_duration then
    return constants.max_duration
  end
  return duration
end

function M.normalize_interpolation(value)
  if constants.interpolation_set[value] then
    return value
  end
  return nil
end

function M.normalize_loop(value)
  if constants.loop_set[value] then
    return value
  end
  return nil
end

local function normalize_optional_duration(value)
  if value == nil then
    return M.default_duration
  end
  if type(value) ~= 'number' or not numbers.is_finite(value) then
    return nil
  end
  return M.normalize_duration(value)
end

local function normalize_optional_interpolation(value)
  if value == nil then
    return M.default_interpolation
  end
  return M.normalize_interpolation(value)
end

local function normalize_optional_loop(value)
  if value == nil then
    return M.default_loop
  end
  return M.normalize_loop(value)
end

local function normalize_optional_phase(value)
  if value == nil then
    return M.default_phase
  end
  if not numbers.is_finite(value) then
    return nil
  end
  return numbers.unit(value, 0)
end

function M.normalize_color_ref(value)
  if type(value) ~= 'string' then
    return nil
  end

  if color_refs[value] then
    return value
  end

  local normalized = color.normalize(value)
  if normalized and normalized ~= 'NONE' then
    return normalized
  end
  return nil
end

local function normalize_value_stop(stop)
  if
    type(stop) ~= 'table'
    or not tables.has_only_keys(stop, value_stop_keys)
    or type(stop.value) ~= 'number'
    or not numbers.is_finite(stop.value)
  then
    return nil
  end
  local at = normalize_at(stop.at)
  if at == nil then
    return nil
  end

  return {
    at = at,
    value = stop.value,
  }
end

function M.normalize_timeline(timeline)
  return normalize_stop_sequence(timeline, function(stop)
    if type(stop) ~= 'table' or not tables.has_only_keys(stop, color_stop_keys) then
      return nil
    end

    local color_ref = M.normalize_color_ref(stop.color)
    if not color_ref then
      return nil
    end
    local at = normalize_at(stop.at)
    if at == nil then
      return nil
    end

    return {
      at = at,
      color = color_ref,
    }
  end)
end

function M.normalize_transform(transform)
  if
    type(transform) ~= 'table'
    or not tables.has_only_keys(transform, transform_keys)
    or not constants.transform_type_set[transform.type]
  then
    return nil
  end

  local normalized_timeline = normalize_stop_sequence(transform.timeline, normalize_value_stop)
  if not normalized_timeline then
    return nil
  end
  local interpolation = normalize_optional_interpolation(transform.interpolation)
  if not interpolation then
    return nil
  end

  return {
    type = transform.type,
    interpolation = interpolation,
    timeline = normalized_timeline,
  }
end

function M.normalize_transforms(transforms)
  if transforms == nil then
    return {}
  end
  if not tables.is_sequence(transforms) then
    return nil
  end

  local normalized = {}
  for _, transform in ipairs(transforms) do
    local normalized_transform = M.normalize_transform(transform)
    if not normalized_transform then
      return nil
    end
    normalized[#normalized + 1] = normalized_transform
  end
  return normalized
end

function M.default_spec(preset)
  local presets = require('hlcraft.dynamic.presets')
  if preset == nil then
    return presets.default()
  end
  return presets.get(preset)
end

function M.normalize_channel(spec)
  if type(spec) ~= 'table' or not tables.has_only_keys(spec, channel_keys) or spec.version ~= M.version then
    return nil
  end

  local timeline = M.normalize_timeline(spec.timeline)
  if not timeline then
    return nil
  end

  local transforms = M.normalize_transforms(spec.transforms)
  if not transforms then
    return nil
  end

  local preset = nil
  if spec.preset ~= nil then
    if type(spec.preset) ~= 'string' or spec.preset == '' then
      return nil
    end
    preset = spec.preset
  end

  local duration = normalize_optional_duration(spec.duration)
  local loop = normalize_optional_loop(spec.loop)
  local phase = normalize_optional_phase(spec.phase)
  local interpolation = normalize_optional_interpolation(spec.interpolation)
  if duration == nil or loop == nil or phase == nil or interpolation == nil then
    return nil
  end

  return {
    version = M.version,
    preset = preset,
    duration = duration,
    loop = loop,
    phase = phase,
    interpolation = interpolation,
    timeline = timeline,
    transforms = transforms,
  }
end

function M.normalize_dynamic(dynamic)
  if type(dynamic) ~= 'table' or not tables.has_only_keys(dynamic, M.channel_set) then
    return nil
  end

  local normalized = {}
  for _, channel in ipairs(M.channels) do
    if dynamic[channel] ~= nil then
      local spec = M.normalize_channel(dynamic[channel])
      if not spec then
        return nil
      end
      normalized[channel] = spec
    end
  end

  if next(normalized) == nil then
    return nil
  end
  return normalized
end

local function compact_transform(transform)
  local compacted = {
    type = transform.type,
    timeline = transform.timeline,
  }
  if transform.interpolation ~= M.default_interpolation then
    compacted.interpolation = transform.interpolation
  end
  return compacted
end

function M.compact_channel(spec)
  local normalized = M.normalize_channel(spec)
  if not normalized then
    return nil
  end

  local compacted = {
    version = normalized.version,
    timeline = normalized.timeline,
  }
  if normalized.preset ~= nil then
    compacted.preset = normalized.preset
  end
  if normalized.duration ~= M.default_duration then
    compacted.duration = normalized.duration
  end
  if normalized.loop ~= M.default_loop then
    compacted.loop = normalized.loop
  end
  if normalized.phase ~= M.default_phase then
    compacted.phase = normalized.phase
  end
  if normalized.interpolation ~= M.default_interpolation then
    compacted.interpolation = normalized.interpolation
  end
  if #normalized.transforms > 0 then
    compacted.transforms = {}
    for _, transform in ipairs(normalized.transforms) do
      compacted.transforms[#compacted.transforms + 1] = compact_transform(transform)
    end
  end

  return compacted
end

function M.compact_dynamic(dynamic)
  local normalized = M.normalize_dynamic(dynamic)
  if not normalized then
    return nil
  end

  local compacted = {}
  for _, channel in ipairs(M.channels) do
    local spec = M.compact_channel(normalized[channel])
    if spec then
      compacted[channel] = spec
    end
  end

  if next(compacted) == nil then
    return nil
  end
  return compacted
end

return M
