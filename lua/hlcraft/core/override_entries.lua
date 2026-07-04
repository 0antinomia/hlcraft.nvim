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

local function entry_label(opts)
  return opts and opts.label or 'override entry'
end

local function set_normalized(entry, key, value)
  local field_value = override_values.entry_value(value)
  if field_value ~= nil then
    entry[key] = field_value
  end
end

function M.normalize(entry, opts)
  local label = entry_label(opts)
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
    if opts and opts.compact_dynamic then
      normalized.dynamic = dynamic_model.compact_dynamic(dynamic)
    else
      normalized.dynamic = dynamic
    end
  end

  return normalized, nil
end

return M
