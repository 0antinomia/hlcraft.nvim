local fields = require('hlcraft.core.fields')
local dynamic_model = require('hlcraft.dynamic.model')
local override_values = require('hlcraft.core.override_values')

local M = {}

local function assert_table(value, label)
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  return value
end

local function normalize_entry_options(opts)
  if opts == nil then
    return {}
  end
  opts = assert_table(opts, 'persistence entry options')
  if opts.compact_dynamic ~= nil and type(opts.compact_dynamic) ~= 'boolean' then
    error('persistence entry compact_dynamic option must be boolean', 3)
  end
  return opts
end

local entry_keys = {
  dynamic = true,
}
for _, key in ipairs(fields.override_keys) do
  entry_keys[key] = true
end

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

local function normalize_dynamic_fields(entry, normalized, opts)
  local dynamic = dynamic_model.normalize_dynamic(entry.dynamic)
  if not dynamic then
    return
  end

  if opts.compact_dynamic then
    normalized.dynamic = dynamic_model.compact_dynamic(dynamic)
  else
    normalized.dynamic = dynamic
  end
end

function M.normalize_entry(entry, opts)
  entry = assert_table(entry, 'persistence entry')
  opts = normalize_entry_options(opts)
  local normalized = {}

  normalize_override_fields(entry, normalized)
  normalize_dynamic_fields(entry, normalized, opts)

  return normalized
end

function M.compact_entry(entry)
  return M.normalize_entry(entry, { compact_dynamic = true })
end

function M.compact_entry_strict(name, entry)
  for key, _ in pairs(entry) do
    if not entry_keys[key] then
      return nil, ('Highlight %s has unsupported field: %s'):format(name, key)
    end
  end

  local normalized = {}
  for _, key in ipairs(fields.override_keys) do
    if entry[key] ~= nil then
      local value, err = override_values.normalize_field(key, entry[key])
      if err then
        return nil, ('Highlight %s has invalid %s: %s'):format(name, key, err)
      end
      set_normalized(normalized, key, value)
    end
  end

  if entry.dynamic ~= nil then
    local dynamic = dynamic_model.normalize_dynamic(entry.dynamic)
    if not dynamic then
      return nil, ('Highlight %s has invalid dynamic override'):format(name)
    end
    normalized.dynamic = dynamic_model.compact_dynamic(dynamic)
  end

  return normalized, nil
end

function M.normalize_loaded_data(data)
  data = assert_table(data, 'loaded persistence data')
  data.entries = assert_table(data.entries, 'loaded persistence entries')
  data.sections = assert_table(data.sections, 'loaded persistence sections')
  data.groups = assert_table(data.groups, 'loaded persistence groups')

  local normalized_by_name = {}
  for name, entry in pairs(data.entries) do
    local normalized = M.normalize_entry(entry)
    data.entries[name] = normalized
    normalized_by_name[name] = normalized
  end

  for _, entries in pairs(data.sections) do
    entries = assert_table(entries, 'loaded persistence section entries')
    for name, entry in pairs(entries) do
      entries[name] = normalized_by_name[name] or M.normalize_entry(entry)
    end
  end

  return data
end

function M.normalize_entries(entries)
  entries = assert_table(entries, 'persistence entries')
  local normalized = {}
  for name, entry in pairs(entries) do
    normalized[name] = M.compact_entry(entry)
  end
  return normalized
end

function M.normalize_entries_strict(entries)
  entries = assert_table(entries, 'persistence entries')
  local normalized = {}
  for name, entry in pairs(entries) do
    local compacted, err = M.compact_entry_strict(name, entry)
    if err then
      return nil, err
    end
    normalized[name] = compacted
  end
  return normalized, nil
end

return M
