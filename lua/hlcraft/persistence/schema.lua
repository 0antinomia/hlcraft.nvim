local fields = require('hlcraft.core.fields')
local override_values = require('hlcraft.core.override_values')

local M = {}

local function set_normalized(entry, key, value)
  local field_value = override_values.entry_value(value)
  if field_value ~= nil then
    entry[key] = field_value
  end
end

local function normalize_color_fields(entry, normalized)
  for _, key in ipairs(fields.color_keys) do
    if entry[key] ~= nil then
      local value = override_values.normalize_color(entry[key])
      set_normalized(normalized, key, value)
    end
  end
end

local function normalize_style_fields(entry, normalized)
  for _, key in ipairs(fields.style_keys) do
    if entry[key] ~= nil then
      local value = override_values.normalize_style(key, entry[key])
      set_normalized(normalized, key, value)
    end
  end
end

local function normalize_numeric_fields(entry, normalized)
  if entry.blend ~= nil then
    local value = override_values.normalize_blend(entry.blend)
    set_normalized(normalized, 'blend', value)
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

  normalize_color_fields(entry, normalized)
  normalize_style_fields(entry, normalized)
  normalize_numeric_fields(entry, normalized)
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
