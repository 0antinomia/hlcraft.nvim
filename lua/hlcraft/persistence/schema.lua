local override_entries = require('hlcraft.core.override_entries')

local M = {}

local function assert_table(value, label)
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  return value
end

local function assert_non_empty_string(value, label)
  if type(value) ~= 'string' or vim.trim(value) == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return value
end

local function assert_entry_exists(data, name, label)
  if data.entries[name] == nil then
    error(('%s %s has no entry'):format(label, name), 3)
  end
end

local function assert_group_exists(data, name, label)
  local group_name = data.groups[name]
  if group_name == nil then
    error(('%s %s has no group'):format(label, name), 3)
  end
  return group_name
end

local function assert_section_contains(data, section_name, name)
  local section = data.sections[section_name]
  if type(section) ~= 'table' or section[name] == nil then
    error(('loaded persistence entry %s is missing from section %s'):format(name, section_name), 3)
  end
end

local function normalize_entry_options(opts)
  if opts == nil then
    return {}
  end
  opts = assert_table(opts, 'persistence entry options')
  for key in pairs(opts) do
    if key ~= 'compact_dynamic' then
      error(('unknown persistence entry option: %s'):format(tostring(key)), 3)
    end
  end
  if opts.compact_dynamic ~= nil and type(opts.compact_dynamic) ~= 'boolean' then
    error('persistence entry compact_dynamic option must be boolean', 3)
  end
  return opts
end

function M.normalize_entry(name, entry, opts)
  name = assert_non_empty_string(name, 'persistence highlight name')
  entry = assert_table(entry, ('persistence entry %s'):format(tostring(name)))
  opts = normalize_entry_options(opts)

  return override_entries.normalize(entry, {
    compact_dynamic = opts.compact_dynamic,
    label = ('Highlight %s'):format(name),
  })
end

function M.normalize_loaded_data(data)
  data = assert_table(data, 'loaded persistence data')
  data.entries = assert_table(data.entries, 'loaded persistence entries')
  data.sections = assert_table(data.sections, 'loaded persistence sections')
  data.groups = assert_table(data.groups, 'loaded persistence groups')

  local normalized_data = {
    entries = {},
    groups = {},
    sections = {},
  }

  for name, group_name in pairs(data.groups) do
    assert_non_empty_string(name, 'loaded persistence highlight name')
    assert_non_empty_string(group_name, ('loaded persistence group for %s'):format(name))
    assert_entry_exists(data, name, 'loaded persistence group')
    normalized_data.groups[name] = group_name
  end

  local normalized_by_name = {}
  for name, entry in pairs(data.entries) do
    assert_non_empty_string(name, 'loaded persistence highlight name')
    local group_name = assert_group_exists(data, name, 'loaded persistence entry')
    assert_section_contains(data, group_name, name)
    local normalized, err = M.normalize_entry(name, entry)
    if err then
      error(err, 2)
    end
    normalized_data.entries[name] = normalized
    normalized_by_name[name] = normalized
  end

  for section_name, entries in pairs(data.sections) do
    assert_non_empty_string(section_name, 'loaded persistence section name')
    entries = assert_table(entries, 'loaded persistence section entries')
    local section = {}
    for name, entry in pairs(entries) do
      assert_non_empty_string(name, 'loaded persistence highlight name')
      local group_name = assert_group_exists(data, name, 'loaded persistence section entry')
      if group_name ~= section_name then
        error(('loaded persistence section %s contains %s assigned to %s'):format(section_name, name, group_name), 3)
      end
      if normalized_by_name[name] then
        section[name] = normalized_by_name[name]
      else
        local normalized, err = M.normalize_entry(name, entry)
        if err then
          error(err, 2)
        end
        section[name] = normalized
      end
    end
    normalized_data.sections[section_name] = section
  end

  return normalized_data
end

function M.normalize_entries(entries)
  entries = assert_table(entries, 'persistence entries')
  local normalized = {}
  for name, entry in pairs(entries) do
    local compacted, err = M.normalize_entry(name, entry, { compact_dynamic = true })
    if err then
      return nil, err
    end
    normalized[name] = compacted
  end
  return normalized, nil
end

return M
