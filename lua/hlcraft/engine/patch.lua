local M = {}

local color = require('hlcraft.core.color')
local dynamic_model = require('hlcraft.dynamic.model')
local store = require('hlcraft.engine.store')

local color_key_set = {}
for _, key in ipairs(store.color_keys) do
  color_key_set[key] = true
end

local style_key_set = {}
for _, key in ipairs(store.style_keys) do
  style_key_set[key] = true
end

local patch_key_set = {
  group = true,
  dynamic = true,
}

for _, key in ipairs(store.override_keys) do
  patch_key_set[key] = true
end

function M.is_color_key(key)
  return color_key_set[key] == true
end

function M.is_style_key(key)
  return style_key_set[key] == true
end

function M.is_dynamic_key(key)
  return dynamic_model.channel_set[key] == true
end

function M.is_unset(value)
  return value == nil or value == vim.NIL or (type(value) == 'string' and vim.trim(value) == '')
end

local function normalize_blend(value)
  if M.is_unset(value) then
    return vim.NIL, nil
  end

  local number_value = tonumber(value)
  if number_value == nil then
    return nil, 'Blend override must be a number or empty'
  end

  if number_value < 0 or number_value > 100 then
    return nil, 'Blend override must be between 0 and 100'
  end

  return math.floor(number_value), nil
end

local function normalize_color(value)
  if M.is_unset(value) then
    return vim.NIL, nil
  end

  local normalized, err = color.normalize(value)
  if err then
    return nil, err
  end
  return normalized, nil
end

local function normalize_style(key, value)
  if value == vim.NIL then
    return vim.NIL, nil
  end

  if value ~= nil and type(value) ~= 'boolean' then
    return nil, ('Style override %s must be boolean or nil'):format(key)
  end

  return value == nil and vim.NIL or value, nil
end

local function normalize_dynamic_channel(key, value)
  if M.is_unset(value) then
    return vim.NIL, nil
  end

  local normalized = dynamic_model.normalize_channel(value)
  if not normalized then
    return nil, ('Invalid dynamic spec for %s'):format(key)
  end

  return normalized, nil
end

local function entry_value(value)
  if value == vim.NIL then
    return nil
  end
  return value
end

function M.validate(patch)
  if type(patch) ~= 'table' then
    return false, 'Patch must be a table'
  end

  for key, _ in pairs(patch) do
    if not patch_key_set[key] then
      return false, ('Unsupported override key: %s'):format(tostring(key))
    end
  end

  if patch.dynamic ~= nil and type(patch.dynamic) ~= 'table' then
    return false, 'dynamic patch must be a table'
  end

  if patch.dynamic ~= nil then
    for key, _ in pairs(patch.dynamic) do
      if not M.is_dynamic_key(key) then
        return false, ('Unsupported dynamic key: %s'):format(tostring(key))
      end
    end
  end

  return true, nil
end

function M.normalize(patch)
  local valid, validation_err = M.validate(patch)
  if not valid then
    return nil, validation_err
  end

  local normalized = {}

  if patch.group ~= nil then
    normalized.group = M.is_unset(patch.group) and vim.NIL or vim.trim(tostring(patch.group))
  end

  for _, key in ipairs(store.color_keys) do
    if patch[key] ~= nil then
      local value, err = normalize_color(patch[key])
      if err then
        return nil, err
      end
      normalized[key] = value
    end
  end

  for _, key in ipairs(store.style_keys) do
    if patch[key] ~= nil then
      local value, err = normalize_style(key, patch[key])
      if err then
        return nil, err
      end
      normalized[key] = value
    end
  end

  if patch.blend ~= nil then
    local value, err = normalize_blend(patch.blend)
    if err then
      return nil, err
    end
    normalized.blend = value
  end

  if patch.dynamic ~= nil then
    normalized.dynamic = {}
    for _, key in ipairs(dynamic_model.channels) do
      if patch.dynamic[key] ~= nil then
        local value, err = normalize_dynamic_channel(key, patch.dynamic[key])
        if err then
          return nil, err
        end
        normalized.dynamic[key] = value
      end
    end
  end

  return normalized, nil
end

function M.apply_entry(entry, patch)
  for _, key in ipairs(store.color_keys) do
    if patch[key] ~= nil then
      entry[key] = entry_value(patch[key])
    end
  end

  for _, key in ipairs(store.style_keys) do
    if patch[key] ~= nil then
      entry[key] = entry_value(patch[key])
    end
  end

  if patch.blend ~= nil then
    entry.blend = entry_value(patch.blend)
  end

  if type(patch.dynamic) == 'table' then
    entry.dynamic = type(entry.dynamic) == 'table' and entry.dynamic or {}
    for _, key in ipairs(dynamic_model.channels) do
      if patch.dynamic[key] ~= nil then
        entry.dynamic[key] = entry_value(patch.dynamic[key])
      end
    end
  end
end

function M.changes_entry(patch)
  if patch.blend ~= nil then
    return true
  end

  for _, key in ipairs(store.color_keys) do
    if patch[key] ~= nil then
      return true
    end
  end
  for _, key in ipairs(store.style_keys) do
    if patch[key] ~= nil then
      return true
    end
  end

  return type(patch.dynamic) == 'table'
end

return M
