local fields = require('hlcraft.core.fields')
local override_values = require('hlcraft.core.override_values')

local M = {}

local function set_normalized(entry, key, value)
  local field_value = override_values.entry_value(value)
  if field_value ~= nil then
    entry[key] = field_value
  end
end

local function normalize_override_fields(entry, normalized)
  for _, key in ipairs(fields.override_keys) do
    if entry[key] ~= nil then
      local value = override_values.normalize_field(key, entry[key])
      set_normalized(normalized, key, value)
    end
  end
end

local function normalize_dynamic_fields(entry, normalized)
  if type(entry.dynamic) ~= 'table' then
    return
  end

  local dynamic = {}
  for _, key in ipairs(fields.color_keys) do
    if entry.dynamic[key] ~= nil then
      local value = override_values.normalize_dynamic_channel(key, entry.dynamic[key])
      set_normalized(dynamic, key, value)
    end
  end

  if next(dynamic) ~= nil then
    normalized.dynamic = dynamic
  end
end

function M.normalize_entry(entry)
  entry = entry or {}
  local normalized = {}

  normalize_override_fields(entry, normalized)
  normalize_dynamic_fields(entry, normalized)

  return normalized
end

function M.normalize_loaded_data(data)
  local normalized_by_name = {}
  for name, entry in pairs(data.entries or {}) do
    local normalized = M.normalize_entry(entry)
    data.entries[name] = normalized
    normalized_by_name[name] = normalized
  end

  for _, entries in pairs(data.sections or {}) do
    for name, entry in pairs(entries or {}) do
      entries[name] = normalized_by_name[name] or M.normalize_entry(entry)
    end
  end

  return data
end

function M.normalize_entries(entries)
  local normalized = {}
  for name, entry in pairs(entries or {}) do
    normalized[name] = M.normalize_entry(entry)
  end
  return normalized
end

return M
