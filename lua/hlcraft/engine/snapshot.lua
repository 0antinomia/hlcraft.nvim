local override_entries = require('hlcraft.core.override_entries')
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

function M.normalize_entry(entry, label)
  if entry == nil then
    return nil
  end

  local normalized, err = override_entries.normalize(entry, { label = label or 'entry' })
  if err then
    error(err, 2)
  end

  if next(normalized) == nil then
    return nil
  end

  return normalized
end

function M.normalize_draft_entry(entry)
  return M.normalize_entry(entry, 'draft entry')
end

local function assert_group_name(value, label)
  if value == nil then
    return nil
  end
  if type(value) ~= 'string' then
    error(('%s must be a string'):format(label), 3)
  end
  if vim.trim(value) == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return value
end

function M.ensure_draft_group(name)
  local draft_group = assert_group_name(data.draft_groups[name], 'draft group')
  if draft_group == nil then
    data.draft_groups[name] = assert_group_name(data.persisted_groups[name], 'persisted group')
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
  data.draft[name] = M.normalize_draft_entry(data.draft[name])
  if data.draft[name] == nil then
    data.draft[name] = nil
    data.draft_groups[name] = nil
  end
end

return M
