local fields = require('hlcraft.core.fields')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local util = require('hlcraft.persistence.codec.util')

local M = {}

local key_priority = {}
local next_priority = 10

local function append_priority(key)
  key_priority[key] = next_priority
  next_priority = next_priority + 10
end

for _, key in ipairs(fields.override_keys) do
  append_priority(key)
end

for _, key in ipairs({
  'dynamic',
  'version',
  'preset',
  'duration',
  'loop',
  'phase',
  'type',
  'interpolation',
  'timeline',
  'transforms',
  'at',
  'color',
  'value',
}) do
  append_priority(key)
end

local function ordered_keys(entry)
  if type(entry) ~= 'table' then
    error('TOML inline table must be a table', 3)
  end
  for key in pairs(entry) do
    if type(key) ~= 'string' then
      error('TOML field keys must be strings', 3)
    end
  end

  return tables.sorted_keys(entry, function(left, right)
    local left_priority = key_priority[left] or math.huge
    local right_priority = key_priority[right] or math.huge
    if left_priority == right_priority then
      return left < right
    end
    return left_priority < right_priority
  end)
end

local encode_value

local function encode_array(values)
  local parts = {}
  for _, value in ipairs(values) do
    parts[#parts + 1] = encode_value(value)
  end
  return ('[%s]'):format(table.concat(parts, ', '))
end

function M.inline_table(entry)
  local parts = {}
  for _, key in ipairs(ordered_keys(entry)) do
    parts[#parts + 1] = ('%s = %s'):format(key, encode_value(entry[key]))
  end
  return ('{ %s }'):format(table.concat(parts, ', '))
end

encode_value = function(value)
  if type(value) == 'string' then
    return ('"%s"'):format(util.escape_string(value))
  end
  if type(value) == 'boolean' then
    return value and 'true' or 'false'
  end
  if type(value) == 'number' then
    if not numbers.is_finite(value) then
      error('TOML numbers must be finite', 3)
    end
    return tostring(value)
  end
  if type(value) == 'table' then
    if tables.is_sequence(value) then
      return encode_array(value)
    end
    return M.inline_table(value)
  end
  error(('Unsupported TOML value type: %s'):format(type(value)), 3)
end

function M.section(section_name, entries)
  if type(entries) ~= 'table' then
    error('TOML section entries must be a table', 2)
  end
  for highlight_name, entry in pairs(entries) do
    if type(highlight_name) ~= 'string' then
      error('TOML highlight names must be strings', 2)
    end
    if type(entry) ~= 'table' then
      error('TOML highlight entries must be tables', 2)
    end
  end

  local lines = {
    ('["%s"]'):format(util.escape_string(section_name)),
  }
  local highlight_names = tables.sorted_keys(entries)

  for _, highlight_name in ipairs(highlight_names) do
    lines[#lines + 1] = ('"%s" = %s'):format(
      util.escape_string(highlight_name),
      M.inline_table(entries[highlight_name])
    )
  end

  return lines
end

return M
