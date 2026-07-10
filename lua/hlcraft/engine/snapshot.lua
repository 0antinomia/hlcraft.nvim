local override_entries = require('hlcraft.core.override_entries')
local store = require('hlcraft.engine.store')
local tables = require('hlcraft.core.tables')

local M = {}

local data = store.data
local apply_data_keys = {
  'active',
  'base_specs',
  'draft',
  'draft_groups',
  'pending',
}

function M.deepcopy(value)
  return vim.deepcopy(value)
end

function M.rebuild_active()
  data.active = vim.tbl_deep_extend('force', M.deepcopy(data.preset), M.deepcopy(data.draft))
end

function M.refresh_base_specs()
  data.base_specs = {}
end

function M.capture_apply_data()
  local captured = {}
  for _, key in ipairs(apply_data_keys) do
    captured[key] = M.deepcopy(data[key])
  end
  return captured
end

function M.restore_apply_data(captured)
  for _, key in ipairs(apply_data_keys) do
    data[key] = captured[key]
  end
end

function M.normalize_entry(entry, label)
  if entry == nil then
    return nil
  end

  local normalized, err = override_entries.normalize(entry, { label = label or 'entry' })
  if err then
    error(err, 2)
  end
  if normalized == nil then
    error('entry normalization returned no result', 2)
  end

  if next(normalized) == nil then
    return nil
  end

  return normalized
end

function M.normalize_draft_entry(entry)
  return M.normalize_entry(entry, 'draft entry')
end

function M.normalize_group_name(value, label)
  if value == nil then
    return nil
  end
  if type(value) ~= 'string' then
    error(('%s must be a string'):format(label), 3)
  end
  local normalized = vim.trim(value)
  if normalized == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return normalized
end

function M.ensure_draft_group(name)
  local draft_group = M.normalize_group_name(data.draft_groups[name], 'draft group')
  if draft_group ~= nil then
    data.draft_groups[name] = draft_group
    return
  end
  data.draft_groups[name] = M.normalize_group_name(data.persisted_groups[name], 'persisted group')
end

function M.known_groups()
  local groups = {}

  for _, group_name in pairs(data.persisted_groups) do
    local normalized = M.normalize_group_name(group_name, 'persisted group')
    if normalized ~= nil then
      groups[normalized] = true
    end
  end
  for _, group_name in pairs(data.draft_groups) do
    local normalized = M.normalize_group_name(group_name, 'draft group')
    if normalized ~= nil then
      groups[normalized] = true
    end
  end

  return tables.sorted_keys(groups)
end

return M
