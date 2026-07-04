local M = {}

local highlights = require('hlcraft.core.highlights')
local applier = require('hlcraft.engine.applier')
local patch_model = require('hlcraft.engine.patch')
local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local data = store.data

local function assert_name(name)
  if type(name) ~= 'string' or name == '' then
    error('highlight name must be a non-empty string', 3)
  end
  return name
end

local function draft_entry(name)
  local entry = data.draft[name]
  if entry == nil then
    return {}
  end
  if type(entry) ~= 'table' then
    error('draft entry must be a table', 2)
  end
  return snapshot.deepcopy(entry)
end

local function restore(name, entry, group)
  data.draft[name] = snapshot.deepcopy(entry)
  data.draft_groups[name] = group
  snapshot.rebuild_active()
  applier.apply_group(name)
end

--- Atomically mutate one draft highlight entry.
--- @param name string Highlight group name
--- @param patch table
--- @return boolean ok
--- @return string|nil err
function M.apply_patch(name, patch_spec)
  name = assert_name(name)
  local normalized_patch, validation_err = patch_model.normalize(patch_spec)
  if not normalized_patch then
    return false, validation_err
  end

  local previous_entry = snapshot.deepcopy(data.draft[name])
  local previous_group = data.draft_groups[name]
  local entry = draft_entry(name)

  local function fail(err)
    restore(name, previous_entry, previous_group)
    return false, err
  end

  patch_model.apply_entry(entry, normalized_patch)
  local compacted_entry = snapshot.compact_entry(entry)
  if normalized_patch.group ~= nil and patch_model.is_unset(normalized_patch.group) and compacted_entry ~= nil then
    return fail('Group name is required for non-empty override')
  end

  if normalized_patch.group ~= nil then
    if patch_model.is_unset(normalized_patch.group) then
      data.draft_groups[name] = nil
    else
      data.draft_groups[name] = normalized_patch.group
      data.draft[name] = entry
    end
  elseif patch_model.changes_entry(normalized_patch) then
    snapshot.ensure_draft_group(name)
  end

  if patch_model.changes_entry(normalized_patch) then
    data.draft[name] = compacted_entry
    if data.draft[name] == nil then
      data.draft_groups[name] = nil
    end
  elseif normalized_patch.group ~= nil and data.draft[name] == nil and data.draft_groups[name] ~= nil then
    data.draft[name] = entry
  end

  snapshot.rebuild_active()
  applier.apply_group(name)
  return true, nil
end

--- Toggle one boolean style override against the current live highlight.
--- @param name string
--- @param key string
--- @return boolean ok
--- @return boolean|nil value
--- @return string|nil err
function M.toggle_style(name, key)
  name = assert_name(name)
  local current = highlights.get_group(name)
  if not current then
    return false, nil, ('Unknown highlight group: %s'):format(name)
  end

  local active = data.active[name] and data.active[name][key]
  local next_value = active
  if next_value == nil then
    next_value = not current[key]
  else
    next_value = not next_value
  end

  local ok, err = M.apply_patch(name, { [key] = next_value })
  if not ok then
    return false, nil, err
  end
  return true, next_value, nil
end

return M
