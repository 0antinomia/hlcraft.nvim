local M = {}

local storage = require('hlcraft.persistence.repository')
local applier = require('hlcraft.engine.applier')
local mutations = require('hlcraft.engine.mutations')
local patch_model = require('hlcraft.engine.patch')
local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local data = store.data

--- Bootstrap draft overrides and automatic reapplication after colorscheme changes.
--- @param force boolean|nil Force re-bootstrap even if already bootstrapped
--- @return nil
function M.bootstrap(force)
  if data.bootstrapped and not force then
    return
  end

  if data.bootstrapped and data.group then
    pcall(vim.api.nvim_del_augroup_by_id, data.group)
  end

  local loaded = storage.load()
  data.persisted = snapshot.deepcopy(loaded.entries or {})
  data.persisted_groups = snapshot.deepcopy(loaded.groups or {})
  data.draft = snapshot.deepcopy(data.persisted)
  data.draft_groups = snapshot.deepcopy(data.persisted_groups)
  data.runtime = data.draft
  data.runtime_groups = data.draft_groups
  data.preset = applier.build_preset_overrides()
  snapshot.rebuild_active()
  data.pending = {}
  applier.refresh_base_specs()

  data.group = vim.api.nvim_create_augroup('HlcraftOverrides', { clear = true })
  applier.register_reapply_events(function()
    M.apply_all()
  end)

  data.bootstrapped = true
  M.apply_all()

  if next(data.pending) ~= nil then
    applier.install_pending_hook()
  end

  require('hlcraft.dynamic.runtime').start()
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
  return snapshot.deepcopy(data.draft[name] or {})
end

--- Return the persisted override for a group.
--- @param name string
--- @return table
function M.get_persisted(name)
  return snapshot.deepcopy(data.persisted[name] or {})
end

--- Return the current draft TOML section for a highlight group.
--- @param name string
--- @return string
function M.get_draft_group(name)
  return data.draft_groups[name]
end

M.get_runtime_group = M.get_draft_group

--- Return the persisted TOML section for a highlight group.
--- @param name string
--- @return string
function M.get_persisted_group(name)
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
  data.draft[name] = snapshot.deepcopy(data.persisted[name])
  data.draft_groups[name] = data.persisted_groups[name]
  snapshot.rebuild_active()
  applier.refresh_base_specs()
  applier.apply_group(name)
end

--- Set the draft TOML section for a highlight group.
--- @param name string
--- @param group_name string|nil
--- @return boolean ok
--- @return string|nil err
function M.set_group(name, group_name)
  local normalized = vim.trim(tostring(group_name or ''))
  if normalized == '' then
    return false, 'Group name is required'
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
  return mutations.apply_patch(name, { blend = value == nil and vim.NIL or value })
end

--- Atomically apply a draft mutation patch.
--- @param name string
--- @param patch table
--- @return boolean ok
--- @return string|nil err
function M.apply_patch(name, patch)
  return mutations.apply_patch(name, patch)
end

--- Remove all draft overrides for one highlight group and restore its base highlight.
--- @param name string Highlight group name
--- @return nil
function M.clear(name)
  data.draft[name] = nil
  data.draft_groups[name] = nil
  snapshot.rebuild_active()
  applier.apply_group(name)
end

--- Persist the current draft overrides to the configured hlcraft directory.
--- @return boolean ok
--- @return string|nil err
function M.save()
  local persisted = snapshot.deepcopy(data.draft)
  local persisted_groups = snapshot.deepcopy(data.draft_groups)
  local ok, err = storage.save(persisted, persisted_groups)
  if not ok then
    return false, err
  end

  data.persisted = persisted
  data.persisted_groups = persisted_groups
  return true, nil
end

--- Return whether a group currently has draft overrides.
--- @param name string
--- @return boolean
function M.has_draft(name)
  return data.draft[name] ~= nil and next(data.draft[name]) ~= nil
end

M.has_runtime = M.has_draft

--- Return whether a group currently has persisted overrides.
--- @param name string
--- @return boolean
function M.has_persisted(name)
  return data.persisted[name] ~= nil and next(data.persisted[name]) ~= nil
end

--- Return the storage path used for persisted overrides.
--- @return string
function M.path()
  return storage.path()
end

--- Return the concrete TOML file path currently used for one highlight group.
--- @param name string
--- @return string|nil
function M.file_path(name)
  return storage.file_path(M.get_draft_group(name))
end

return M
