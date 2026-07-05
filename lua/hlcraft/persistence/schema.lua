local highlight_names = require('hlcraft.core.highlight_names')
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

local function normalize_non_empty_string(value, label)
  return vim.trim(assert_non_empty_string(value, label))
end

local function assert_highlight_name(value, label)
  return highlight_names.assert(value, label, 3)
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
  return normalize_non_empty_string(group_name, ('%s group for %s'):format(label, name))
end

local function normalized_section_keys(data)
  local keys = {}
  for section_name, entries in pairs(data.sections) do
    local normalized = normalize_non_empty_string(section_name, 'loaded persistence section name')
    assert_table(entries, 'loaded persistence section entries')
    if keys[normalized] ~= nil then
      error(('loaded persistence section %s is defined more than once'):format(normalized), 3)
    end
    keys[normalized] = section_name
  end
  return keys
end

local function assert_section_contains(data, section_keys, section_name, name)
  local raw_section_name = section_keys[section_name]
  local section = raw_section_name and data.sections[raw_section_name]
  if type(section) ~= 'table' or section[name] == nil then
    error(('loaded persistence entry %s is missing from section %s'):format(name, section_name), 3)
  end
end

local function normalize_section_entry(name, entry)
  local normalized, err = M.normalize_entry(name, entry)
  if err then
    error(err, 2)
  end
  return normalized
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
  name = assert_highlight_name(name, 'persistence highlight name')
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
  local section_keys = normalized_section_keys(data)

  for name, group_name in pairs(data.groups) do
    assert_highlight_name(name, 'loaded persistence highlight name')
    group_name = normalize_non_empty_string(group_name, ('loaded persistence group for %s'):format(name))
    assert_entry_exists(data, name, 'loaded persistence group')
    normalized_data.groups[name] = group_name
  end

  local normalized_by_name = {}
  for name, entry in pairs(data.entries) do
    assert_highlight_name(name, 'loaded persistence highlight name')
    local group_name = assert_group_exists(data, name, 'loaded persistence entry')
    assert_section_contains(data, section_keys, group_name, name)
    local normalized, err = M.normalize_entry(name, entry)
    if err then
      error(err, 2)
    end
    normalized_data.entries[name] = normalized
    normalized_by_name[name] = normalized
  end

  for section_name, entries in pairs(data.sections) do
    section_name = normalize_non_empty_string(section_name, 'loaded persistence section name')
    entries = assert_table(entries, 'loaded persistence section entries')
    local section = {}
    for name, entry in pairs(entries) do
      assert_highlight_name(name, 'loaded persistence highlight name')
      local group_name = assert_group_exists(data, name, 'loaded persistence section entry')
      if group_name ~= section_name then
        error(('loaded persistence section %s contains %s assigned to %s'):format(section_name, name, group_name), 3)
      end
      if normalized_by_name[name] then
        local normalized = normalize_section_entry(name, entry)
        if not vim.deep_equal(normalized, normalized_by_name[name]) then
          error(('loaded persistence section %s contains divergent entry %s'):format(section_name, name), 3)
        end
        section[name] = normalized_by_name[name]
      else
        section[name] = normalize_section_entry(name, entry)
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
