local M = {}

M.channels = { 'fg', 'bg', 'sp' }
M.channel_set = { fg = true, bg = true, sp = true }
M.modes = { 'rgb', 'breath' }
M.mode_set = { rgb = true, breath = true }
M.default_speed = 2000
M.min_speed = 250
M.max_speed = 10000

local function is_finite_number(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function M.default_spec()
  return {
    mode = 'rgb',
    speed = M.default_speed,
    params = {},
    palette = nil,
  }
end

function M.normalize_speed(value)
  local speed = tonumber(value)
  if not is_finite_number(speed) then
    return M.default_speed
  end

  speed = math.floor(speed)
  if speed < M.min_speed then
    return M.min_speed
  end
  if speed > M.max_speed then
    return M.max_speed
  end
  return speed
end

function M.normalize_channel(spec)
  if type(spec) ~= 'table' or not M.mode_set[spec.mode] then
    return nil
  end

  return {
    mode = spec.mode,
    speed = M.normalize_speed(spec.speed),
    params = type(spec.params) == 'table' and vim.deepcopy(spec.params) or {},
    palette = type(spec.palette) == 'table' and vim.deepcopy(spec.palette) or nil,
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

function M.inflate_entry(entry)
  local result = vim.deepcopy(entry or {})
  local dynamic = type(result.dynamic) == 'table' and vim.deepcopy(result.dynamic) or {}

  for _, channel in ipairs(M.channels) do
    local mode_key = ('dyn_%s_mode'):format(channel)
    local speed_key = ('dyn_%s_speed'):format(channel)

    if result[mode_key] ~= nil or result[speed_key] ~= nil then
      dynamic[channel] = {
        mode = result[mode_key],
        speed = result[speed_key],
      }
    end

    result[mode_key] = nil
    result[speed_key] = nil
  end

  result.dynamic = M.normalize_dynamic(dynamic)
  return result
end

function M.flatten_entry(entry)
  local result = vim.deepcopy(entry or {})
  local dynamic = M.normalize_dynamic(result.dynamic)

  result.dynamic = nil
  for _, channel in ipairs(M.channels) do
    result[('dyn_%s_mode'):format(channel)] = nil
    result[('dyn_%s_speed'):format(channel)] = nil

    local spec = dynamic and dynamic[channel] or nil
    if spec then
      result[('dyn_%s_mode'):format(channel)] = spec.mode
      result[('dyn_%s_speed'):format(channel)] = spec.speed
    end
  end

  return result
end

function M.has_dynamic(entry)
  return type(entry) == 'table' and M.normalize_dynamic(entry.dynamic) ~= nil
end

return M
