local color = require('hlcraft.core.color')

local M = {}

M.channels = { 'fg', 'bg', 'sp' }
M.channel_set = { fg = true, bg = true, sp = true }

M.version = 1
M.default_duration = 2000

local min_duration = 250
local max_duration = 10000
local color_refs = { base = true, fg = true, bg = true, sp = true }
local interpolation_set = { linear = true, step = true, smooth = true, smoothstep = true, sine = true }
local transform_type_set = { brightness = true, hue_shift = true, saturation = true }

local function is_finite_number(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function valid_loop(value)
  return value == 'repeat' or value == 'pingpong' or value == 'once'
end

local function clamp_unit(value, fallback)
  local number = tonumber(value)
  if not is_finite_number(number) then
    return fallback
  end
  if number < 0 then
    return 0
  end
  if number > 1 then
    return 1
  end
  return number
end

local function normalize_at(value)
  if not is_finite_number(value) then
    return nil
  end
  return clamp_unit(value, 0)
end

function M.normalize_duration(value)
  local duration = tonumber(value)
  if not is_finite_number(duration) then
    return M.default_duration
  end

  duration = math.floor(duration)
  if duration < min_duration then
    return min_duration
  end
  if duration > max_duration then
    return max_duration
  end
  return duration
end

function M.normalize_interpolation(value)
  if interpolation_set[value] then
    return value
  end
  return 'linear'
end

function M.normalize_loop(value)
  if valid_loop(value) then
    return value
  end
  return 'repeat'
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
  if type(stop) ~= 'table' or type(stop.value) ~= 'number' or not is_finite_number(stop.value) then
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
  if type(timeline) ~= 'table' or #timeline == 0 then
    return nil
  end

  local normalized = {}
  for _, stop in ipairs(timeline) do
    if type(stop) ~= 'table' then
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

    normalized[#normalized + 1] = {
      at = at,
      color = color_ref,
    }
  end

  table.sort(normalized, function(left, right)
    return left.at < right.at
  end)

  return normalized
end

function M.normalize_transform(transform)
  if type(transform) ~= 'table' or not transform_type_set[transform.type] then
    return nil
  end

  if type(transform.timeline) ~= 'table' or #transform.timeline == 0 then
    return nil
  end

  local normalized_timeline = {}
  for _, stop in ipairs(transform.timeline) do
    local normalized_stop = normalize_value_stop(stop)
    if not normalized_stop then
      return nil
    end
    normalized_timeline[#normalized_timeline + 1] = normalized_stop
  end

  table.sort(normalized_timeline, function(left, right)
    return left.at < right.at
  end)

  return {
    type = transform.type,
    interpolation = M.normalize_interpolation(transform.interpolation),
    timeline = normalized_timeline,
  }
end

function M.normalize_transforms(transforms)
  if transforms == nil then
    return {}
  end
  if type(transforms) ~= 'table' then
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
  return presets.get(preset or 'pulse')
end

function M.normalize_channel(spec)
  if type(spec) ~= 'table' or spec.version ~= M.version then
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

  local preset = type(spec.preset) == 'string' and spec.preset ~= '' and spec.preset or nil

  return {
    version = M.version,
    preset = preset,
    duration = M.normalize_duration(spec.duration),
    loop = M.normalize_loop(spec.loop),
    phase = clamp_unit(spec.phase, 0),
    interpolation = M.normalize_interpolation(spec.interpolation),
    timeline = timeline,
    transforms = transforms,
  }
end

function M.normalize_dynamic(dynamic)
  if type(dynamic) ~= 'table' then
    return nil
  end

  local normalized = {}
  for _, channel in ipairs(M.channels) do
    local spec = M.normalize_channel(dynamic[channel])
    if spec then
      normalized[channel] = spec
    end
  end

  return next(normalized) and normalized or nil
end

function M.normalize_entry(entry)
  local result = vim.deepcopy(entry or {})
  result.dynamic = M.normalize_dynamic(result.dynamic)
  return result
end

function M.has_dynamic(entry)
  return type(entry) == 'table' and M.normalize_dynamic(entry.dynamic) ~= nil
end

return M
