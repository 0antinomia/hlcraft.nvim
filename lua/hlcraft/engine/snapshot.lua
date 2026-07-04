local dynamic_model = require('hlcraft.dynamic.model')
local store = require('hlcraft.engine.store')
local tables = require('hlcraft.core.tables')

local M = {}

local data = store.data

function M.deepcopy(value)
  return vim.deepcopy(value)
end

function M.rebuild_active()
  data.active = vim.tbl_deep_extend('force', M.deepcopy(data.preset), M.deepcopy(data.draft))
end

function M.refresh_base_specs()
  data.base_specs = {}
end

function M.compact_entry(entry)
  if type(entry) ~= 'table' then
    return nil
  end

  entry.dynamic = dynamic_model.normalize_dynamic(entry.dynamic)
  if next(entry) == nil then
    return nil
  end

  return entry
end

function M.ensure_draft_group(name)
  if data.draft_groups[name] == nil or vim.trim(tostring(data.draft_groups[name])) == '' then
    data.draft_groups[name] = data.persisted_groups[name]
  end
end

function M.known_groups()
  local groups = {}

  for _, group_name in pairs(data.persisted_groups) do
    if type(group_name) == 'string' and vim.trim(group_name) ~= '' then
      groups[group_name] = true
    end
  end
  for _, group_name in pairs(data.draft_groups) do
    if type(group_name) == 'string' and vim.trim(group_name) ~= '' then
      groups[group_name] = true
    end
  end

  return tables.sorted_keys(groups)
end

function M.remove_empty_draft_entry(name)
  data.draft[name] = M.compact_entry(data.draft[name])
  if data.draft[name] == nil then
    data.draft[name] = nil
    data.draft_groups[name] = nil
  end
end

return M
