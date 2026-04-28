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

local function non_empty_table(value)
  return type(value) == 'table' and next(value) ~= nil
end

local function decode_extension(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, value)
  if ok and type(decoded) == 'table' then
    return decoded
  end
  return nil
end

local function encode_extension(value)
  if not non_empty_table(value) then
    return nil
  end

  local ok, encoded = pcall(vim.json.encode, value)
  if ok and type(encoded) == 'string' then
    return encoded
  end
  return nil
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
    local params_key = ('dyn_%s_params'):format(channel)
    local palette_key = ('dyn_%s_palette'):format(channel)
    local params = decode_extension(result[params_key])
    local palette = decode_extension(result[palette_key])

    if result[mode_key] ~= nil or result[speed_key] ~= nil or params ~= nil or palette ~= nil then
      local spec = type(dynamic[channel]) == 'table' and vim.deepcopy(dynamic[channel]) or {}
      if result[mode_key] ~= nil or result[speed_key] ~= nil then
        spec.mode = result[mode_key]
        spec.speed = result[speed_key]
      end
      if params ~= nil then
        spec.params = params
      end
      if palette ~= nil then
        spec.palette = palette
      end
      dynamic[channel] = spec
    end

    result[mode_key] = nil
    result[speed_key] = nil
    result[params_key] = nil
    result[palette_key] = nil
  end

  result.dynamic = M.normalize_dynamic(dynamic)
  return result
end

function M.flatten_entry(entry)
  local result = vim.deepcopy(entry or {})
  local dynamic = M.normalize_dynamic(result.dynamic)

  result.dynamic = nil
  for _, channel in ipairs(M.channels) do
    local mode_key = ('dyn_%s_mode'):format(channel)
    local speed_key = ('dyn_%s_speed'):format(channel)
    local params_key = ('dyn_%s_params'):format(channel)
    local palette_key = ('dyn_%s_palette'):format(channel)

    result[mode_key] = nil
    result[speed_key] = nil
    result[params_key] = nil
    result[palette_key] = nil

    local spec = dynamic and dynamic[channel] or nil
    if spec then
      result[mode_key] = spec.mode
      result[speed_key] = spec.speed
      result[params_key] = encode_extension(spec.params)
      result[palette_key] = encode_extension(spec.palette)
    end
  end

  return result
end

function M.has_dynamic(entry)
  return type(entry) == 'table' and M.normalize_dynamic(entry.dynamic) ~= nil
end

return M
