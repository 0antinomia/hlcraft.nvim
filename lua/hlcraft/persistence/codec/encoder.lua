local fields = require('hlcraft.core.fields')
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
  return tables.sorted_keys(entry, function(left, right)
    local left_priority = key_priority[left] or math.huge
    local right_priority = key_priority[right] or math.huge
    if left_priority == right_priority then
      return tostring(left) < tostring(right)
    end
    return left_priority < right_priority
  end)
end

local encode_value

local function encode_array(values)
  local parts = {}
  for _, value in ipairs(values) do
    local encoded = encode_value(value)
    if encoded == nil then
      return nil
    end
    parts[#parts + 1] = encoded
  end
  return ('[%s]'):format(table.concat(parts, ', '))
end

function M.inline_table(entry)
  local parts = {}
  for _, key in ipairs(ordered_keys(entry)) do
    local encoded = encode_value(entry[key])
    if encoded ~= nil then
      parts[#parts + 1] = ('%s = %s'):format(key, encoded)
    end
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
    return tostring(value)
  end
  if type(value) == 'table' then
    if tables.is_sequence(value) then
      return encode_array(value)
    end
    return M.inline_table(value)
  end
  return nil
end

function M.section(section_name, entries)
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
