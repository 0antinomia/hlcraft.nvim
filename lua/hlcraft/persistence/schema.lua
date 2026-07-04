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

function M.normalize_entry(entry)
  return dynamic_model.normalize_entry(filter_entry(entry))
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
