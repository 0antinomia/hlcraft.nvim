local M = {}

local dynamic_model = require('hlcraft.dynamic.model')
local override_values = require('hlcraft.core.override_values')
local store = require('hlcraft.engine.store')

local patch_key_set = {
  group = true,
  dynamic = true,
}

for _, key in ipairs(store.override_keys) do
  patch_key_set[key] = true
end

function M.is_color_key(key)
  return store.color_set[key] == true
end

function M.is_style_key(key)
  return store.style_set[key] == true
end

function M.is_dynamic_key(key)
  return dynamic_model.channel_set[key] == true
end

M.is_unset = override_values.is_unset

local function assert_table(value, label)
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  return value
end

function M.normalize_group(value)
  if value == vim.NIL then
    return vim.NIL, nil
  end
  if value == nil or (type(value) == 'string' and vim.trim(value) == '') then
    return nil, 'Group name is required'
  end
  if type(value) ~= 'string' then
    return nil, 'Group name must be a string'
  end
  return vim.trim(value), nil
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
    local value, err = M.normalize_group(patch.group)
    if err then
      return nil, err
    end
    normalized.group = value
  end

  for _, key in ipairs(store.override_keys) do
    if patch[key] ~= nil then
      local value, err = override_values.normalize_field(key, patch[key])
      if err then
        return nil, err
      end
      normalized[key] = value
    end
  end

  if patch.dynamic ~= nil then
    normalized.dynamic = {}
    for _, key in ipairs(dynamic_model.channels) do
      if patch.dynamic[key] ~= nil then
        local value, err = override_values.normalize_dynamic_channel(key, patch.dynamic[key])
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
  entry = assert_table(entry, 'patch target entry')
  patch = assert_table(patch, 'normalized patch')

  for _, key in ipairs(store.override_keys) do
    if patch[key] ~= nil then
      entry[key] = override_values.entry_value(patch[key])
    end
  end

  if type(patch.dynamic) == 'table' then
    if entry.dynamic ~= nil and type(entry.dynamic) ~= 'table' then
      error('entry dynamic must be a table', 2)
    end
    if entry.dynamic == nil then
      entry.dynamic = {}
    end
    for _, key in ipairs(dynamic_model.channels) do
      if patch.dynamic[key] ~= nil then
        entry.dynamic[key] = override_values.entry_value(patch.dynamic[key])
      end
    end
    if next(entry.dynamic) == nil then
      entry.dynamic = nil
    end
  end
end

function M.changes_entry(patch)
  patch = assert_table(patch, 'normalized patch')
  for _, key in ipairs(store.override_keys) do
    if patch[key] ~= nil then
      return true
    end
  end

  return type(patch.dynamic) == 'table'
end

return M
