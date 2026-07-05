local dynamic_model = require('hlcraft.dynamic.model')
local fields = require('hlcraft.core.fields')
local override_values = require('hlcraft.core.override_values')

local M = {}

local entry_keys = {
  dynamic = true,
}
for _, key in ipairs(fields.override_keys) do
  entry_keys[key] = true
end

local function normalize_options(opts)
  if opts == nil then
    return {
      label = 'override entry',
      compact_dynamic = false,
    }
  end
  if type(opts) ~= 'table' then
    error('override entry options must be a table', 3)
  end
  for key in pairs(opts) do
    if key ~= 'label' and key ~= 'compact_dynamic' then
      error(('unknown override entry option: %s'):format(tostring(key)), 3)
    end
  end
  local label = opts.label
  if label ~= nil then
    if type(label) ~= 'string' then
      error('override entry label must be a non-empty string or nil', 3)
    end
    label = vim.trim(label)
  end
  if label == '' then
    error('override entry label must be a non-empty string or nil', 3)
  end
  if opts.compact_dynamic ~= nil and type(opts.compact_dynamic) ~= 'boolean' then
    error('override entry compact_dynamic option must be boolean', 3)
  end
  return {
    label = label or 'override entry',
    compact_dynamic = opts.compact_dynamic == true,
  }
end

local function set_normalized(entry, key, value)
  local field_value = override_values.entry_value(value)
  if field_value ~= nil then
    entry[key] = field_value
  end
end

function M.normalize(entry, opts)
  opts = normalize_options(opts)
  local label = opts.label
  if type(entry) ~= 'table' then
    return nil, ('%s must be a table'):format(label)
  end

  for key, _ in pairs(entry) do
    if not entry_keys[key] then
      return nil, ('%s has unsupported field: %s'):format(label, key)
    end
  end

  local normalized = {}
  for _, key in ipairs(fields.override_keys) do
    if entry[key] ~= nil then
      local value, err = override_values.normalize_field(key, entry[key])
      if err then
        return nil, ('%s has invalid %s: %s'):format(label, key, err)
      end
      set_normalized(normalized, key, value)
    end
  end

  if entry.dynamic ~= nil then
    local dynamic = dynamic_model.normalize_dynamic(entry.dynamic)
    if not dynamic then
      return nil, ('%s has invalid dynamic override'):format(label)
    end
    if opts.compact_dynamic then
      normalized.dynamic = dynamic_model.compact_dynamic(dynamic)
    else
      normalized.dynamic = dynamic
    end
  end

  return normalized, nil
end

return M
