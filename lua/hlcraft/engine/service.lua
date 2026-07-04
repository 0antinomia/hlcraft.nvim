local M = {}

local applier = require('hlcraft.engine.applier')
local lifecycle = require('hlcraft.engine.lifecycle')
local mutations = require('hlcraft.engine.mutations')
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

local function normalized_entry_or_empty(entries, name, label)
  return snapshot.normalize_entry(entries[name], label) or {}
end

--- Bootstrap draft overrides and automatic reapplication after colorscheme changes.
--- @param force boolean|nil Force re-bootstrap even if already bootstrapped
--- @return nil
function M.bootstrap(force)
  lifecycle.bootstrap(force, function()
    M.apply_all()
  end)
end

--- Apply all active overrides to the current colorscheme.
--- @return nil
function M.apply_all()
  applier.apply_all()
end

--- Return the active draft override for a group.
--- @param name string
--- @return table
function M.get(name)
  name = assert_name(name)
  return snapshot.deepcopy(normalized_entry_or_empty(data.draft, name, 'draft entry'))
end

--- Return the persisted override for a group.
--- @param name string
--- @return table
function M.get_persisted(name)
  name = assert_name(name)
  return snapshot.deepcopy(normalized_entry_or_empty(data.persisted, name, 'persisted entry'))
end

--- Return the current draft TOML section for a highlight group.
--- @param name string
--- @return string
function M.get_draft_group(name)
  name = assert_name(name)
  return data.draft_groups[name]
end

--- Return the persisted TOML section for a highlight group.
--- @param name string
--- @return string
function M.get_persisted_group(name)
  name = assert_name(name)
  return data.persisted_groups[name]
end

--- Return sorted unique TOML section names known from defaults, persisted, and draft state.
--- @return string[]
function M.known_groups()
  return snapshot.known_groups()
end

--- Restore one draft override and group from persisted state and reapply it.
--- @param name string Highlight group name
--- @return nil
function M.restore_persisted(name)
  name = assert_name(name)
  lifecycle.restore_persisted(name)
end

--- Set the draft TOML section for a highlight group.
--- @param name string
--- @param group_name string|nil
--- @return boolean ok
--- @return string|nil err
function M.set_group(name, group_name)
  name = assert_name(name)
  local normalized, err = patch_model.normalize_group(group_name)
  if err or patch_model.is_unset(normalized) then
    return false, err or 'Group name is required'
  end

  return mutations.apply_patch(name, { group = normalized })
end

--- Set or clear one color override field and apply it immediately.
--- @param name string
--- @param key '"fg"'|'"bg"'|'"sp"'
--- @param value string|nil
--- @return boolean ok
--- @return string|nil err
function M.set_color(name, key, value)
  name = assert_name(name)
  if not patch_model.is_color_key(key) then
    return false, ('Unsupported override key: %s'):format(tostring(key))
  end

  return mutations.apply_patch(name, { [key] = value == nil and vim.NIL or value })
end

--- Set or clear one dynamic color channel and apply it immediately.
--- @param name string
--- @param key '"fg"'|'"bg"'|'"sp"'
--- @param spec table|nil
--- @return boolean ok
--- @return string|nil err
function M.set_dynamic(name, key, spec)
  name = assert_name(name)
  if not patch_model.is_dynamic_key(key) then
    return false, ('Unsupported dynamic key: %s'):format(tostring(key))
  end

  return mutations.apply_patch(name, { dynamic = { [key] = spec == nil and vim.NIL or spec } })
end

--- Set or clear one boolean style override and apply it immediately.
--- @param name string
--- @param key string
--- @param value boolean|nil
--- @return boolean ok
--- @return string|nil err
function M.set_style(name, key, value)
  name = assert_name(name)
  if not patch_model.is_style_key(key) then
    return false, ('Unsupported style key: %s'):format(tostring(key))
  end

  return mutations.apply_patch(name, { [key] = value == nil and vim.NIL or value })
end

--- Toggle one boolean style override against the current live highlight.
--- @param name string
--- @param key string
--- @return boolean ok
--- @return boolean|nil value
--- @return string|nil err
function M.toggle_style(name, key)
  name = assert_name(name)
  if not patch_model.is_style_key(key) then
    return false, nil, ('Unsupported style key: %s'):format(tostring(key))
  end

  return mutations.toggle_style(name, key)
end

--- Set or clear blend override and apply it immediately.
--- @param name string
--- @param value number|nil
--- @return boolean ok
--- @return string|nil err
function M.set_blend(name, value)
  name = assert_name(name)
  return mutations.apply_patch(name, { blend = value == nil and vim.NIL or value })
end

--- Atomically apply a draft mutation patch.
--- @param name string
--- @param patch table
--- @return boolean ok
--- @return string|nil err
function M.apply_patch(name, patch)
  name = assert_name(name)
  return mutations.apply_patch(name, patch)
end

--- Remove all draft overrides for one highlight group and restore its base highlight.
--- @param name string Highlight group name
--- @return nil
function M.clear(name)
  name = assert_name(name)
  lifecycle.clear(name)
end

--- Persist the current draft overrides to the configured hlcraft directory.
--- @return boolean ok
--- @return string|nil err
function M.save()
  return lifecycle.save()
end

--- Return whether a group currently has draft overrides.
--- @param name string
--- @return boolean
function M.has_draft(name)
  name = assert_name(name)
  return next(normalized_entry_or_empty(data.draft, name, 'draft entry')) ~= nil
end

--- Return whether a group currently has persisted overrides.
--- @param name string
--- @return boolean
function M.has_persisted(name)
  name = assert_name(name)
  return next(normalized_entry_or_empty(data.persisted, name, 'persisted entry')) ~= nil
end

--- Return the storage path used for persisted overrides.
--- @return string
function M.path()
  return lifecycle.path()
end

--- Return the concrete TOML file path currently used for one highlight group.
--- @param name string
--- @return string|nil
function M.file_path(name)
  name = assert_name(name)
  return lifecycle.file_path(M.get_draft_group(name))
end

return M
