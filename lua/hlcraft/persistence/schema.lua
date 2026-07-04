local fields = require('hlcraft.core.fields')
local dynamic_model = require('hlcraft.dynamic.model')

local M = {}

local function filter_entry(entry)
  local filtered = {}
  for key, value in pairs(entry or {}) do
    if fields.override_set[key] or key == 'dynamic' then
      filtered[key] = value
    end
  end
  return filtered
end

function M.inflate_entry(entry)
  return dynamic_model.inflate_entry(filter_entry(entry))
end

function M.flatten_entry(entry)
  return dynamic_model.flatten_entry(filter_entry(entry))
end

function M.inflate_data(data)
  local inflated_by_name = {}
  for name, entry in pairs(data.entries or {}) do
    local inflated = M.inflate_entry(entry)
    data.entries[name] = inflated
    inflated_by_name[name] = inflated
  end

  for _, entries in pairs(data.sections or {}) do
    for name, entry in pairs(entries or {}) do
      entries[name] = inflated_by_name[name] or M.inflate_entry(entry)
    end
  end

  return data
end

function M.flatten_entries(entries)
  local flattened = {}
  for name, entry in pairs(entries or {}) do
    flattened[name] = M.flatten_entry(entry)
  end
  return flattened
end

return M
