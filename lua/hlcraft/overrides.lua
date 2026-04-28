local M = {}

local color = require('hlcraft.color')
local dynamic_model = require('hlcraft.dynamic.model')
local highlights = require('hlcraft.highlights')
local storage = require('hlcraft.storage')
local apply = require('hlcraft.overrides.apply')
local override_state = require('hlcraft.overrides.state')

local state = override_state.data

--- Bootstrap runtime overrides and automatic reapplication after colorscheme changes.
--- @param force boolean|nil Force re-bootstrap even if already bootstrapped
--- @return nil
function M.bootstrap(force)
  if state.bootstrapped and not force then
    return
  end

  if state.bootstrapped and state.group then
    pcall(vim.api.nvim_del_augroup_by_id, state.group)
  end

  local loaded = storage.load()
  state.persisted = override_state.deepcopy(loaded.entries or {})
  state.persisted_groups = override_state.deepcopy(loaded.groups or {})
  state.runtime = override_state.deepcopy(state.persisted)
  state.runtime_groups = override_state.deepcopy(state.persisted_groups)
  state.preset = apply.build_preset_overrides()
  override_state.rebuild_active()
  state.pending = {}
  apply.refresh_base_specs()

  state.group = vim.api.nvim_create_augroup('HlcraftOverrides', { clear = true })
  apply.register_reapply_events(function()
    M.apply_all()
  end)

  state.bootstrapped = true
  M.apply_all()

  if next(state.pending) ~= nil then
    apply.install_pending_hook()
  end

  require('hlcraft.dynamic.runtime').start()
end

--- Apply all active overrides to the current colorscheme.
--- @return nil
function M.apply_all()
  apply.apply_all()
end

--- Return the active runtime override for a group.
--- @param name string
--- @return table
function M.get(name)
  return override_state.deepcopy(state.runtime[name] or {})
end

--- Return the persisted override for a group.
--- @param name string
--- @return table
function M.get_persisted(name)
  return override_state.deepcopy(state.persisted[name] or {})
end

--- Return the current runtime TOML section for a highlight group.
--- @param name string
--- @return string
function M.get_runtime_group(name)
  return state.runtime_groups[name] or state.persisted_groups[name]
end

--- Return the persisted TOML section for a highlight group.
--- @param name string
--- @return string
function M.get_persisted_group(name)
  return state.persisted_groups[name]
end

--- Return sorted unique TOML section names known from defaults, persisted, and runtime state.
--- @return string[]
function M.known_groups()
  return override_state.known_groups()
end

--- Restore one runtime override and group from persisted state and reapply it.
--- @param name string Highlight group name
--- @return nil
function M.restore_persisted(name)
  state.runtime[name] = override_state.deepcopy(state.persisted[name])
  state.runtime_groups[name] = state.persisted_groups[name]
  override_state.rebuild_active()
  apply.refresh_base_specs()
  apply.apply_group(name)
end

--- Set the runtime TOML section for a highlight group.
--- @param name string
--- @param group_name string|nil
--- @return boolean ok
--- @return string|nil err
function M.set_group(name, group_name)
  local normalized = vim.trim(tostring(group_name or ''))
  if normalized == '' then
    return false, 'Group name is required'
  end

  if not state.runtime[name] then
    state.runtime[name] = {}
  end

  state.runtime_groups[name] = normalized
  override_state.rebuild_active()
  apply.apply_group(name)
  return true, nil
end

--- Set or clear one color override field and apply it immediately.
--- @param name string
--- @param key '"fg"'|'"bg"'|'"sp"'
--- @param value string|nil
--- @return boolean ok
--- @return string|nil err
function M.set_color(name, key, value)
  if not vim.tbl_contains(override_state.color_keys, key) then
    return false, ('Unsupported override key: %s'):format(tostring(key))
  end

  local normalized, err = color.normalize(value)
  if err then
    return false, err
  end

  override_state.ensure_runtime_group(name)
  state.runtime[name] = state.runtime[name] or {}
  state.runtime[name][key] = normalized

  if state.runtime[name][key] == nil then
    state.runtime[name][key] = nil
  end

  override_state.remove_empty_runtime_entry(name)
  override_state.rebuild_active()
  apply.apply_group(name)
  return true, nil
end

--- Set or clear one dynamic color channel and apply it immediately.
--- @param name string
--- @param key '"fg"'|'"bg"'|'"sp"'
--- @param spec table|nil
--- @return boolean ok
--- @return string|nil err
function M.set_dynamic(name, key, spec)
  if not dynamic_model.channel_set[key] then
    return false, ('Unsupported dynamic key: %s'):format(tostring(key))
  end

  local normalized
  if spec ~= nil then
    normalized = dynamic_model.normalize_channel(spec)
    if not normalized then
      return false, ('Invalid dynamic spec for %s'):format(key)
    end
  end

  override_state.ensure_runtime_group(name)
  state.runtime[name] = state.runtime[name] or {}
  state.runtime[name].dynamic = state.runtime[name].dynamic or {}
  state.runtime[name].dynamic[key] = normalized
  state.runtime[name] = override_state.compact_entry(state.runtime[name])

  if state.runtime[name] == nil then
    state.runtime_groups[name] = nil
  end

  override_state.rebuild_active()
  apply.apply_group(name)
  return true, nil
end

--- Set or clear one boolean style override and apply it immediately.
--- @param name string
--- @param key string
--- @param value boolean|nil
--- @return boolean ok
--- @return string|nil err
function M.set_style(name, key, value)
  if not vim.tbl_contains(override_state.style_keys, key) then
    return false, ('Unsupported style key: %s'):format(tostring(key))
  end

  if value ~= nil and type(value) ~= 'boolean' then
    return false, ('Style override %s must be boolean or nil'):format(key)
  end

  override_state.ensure_runtime_group(name)
  state.runtime[name] = state.runtime[name] or {}
  state.runtime[name][key] = value

  override_state.remove_empty_runtime_entry(name)
  override_state.rebuild_active()
  apply.apply_group(name)
  return true, nil
end

--- Toggle one boolean style override against the current live highlight.
--- @param name string
--- @param key string
--- @return boolean ok
--- @return boolean|nil value
--- @return string|nil err
function M.toggle_style(name, key)
  if not vim.tbl_contains(override_state.style_keys, key) then
    return false, nil, ('Unsupported style key: %s'):format(tostring(key))
  end

  local current = highlights.get_group(name)
  if not current then
    return false, nil, ('Unknown highlight group: %s'):format(name)
  end

  local active = state.active[name] and state.active[name][key]
  local next_value = active
  if next_value == nil then
    next_value = not current[key]
  else
    next_value = not next_value
  end

  local ok, err = M.set_style(name, key, next_value)
  return ok, ok and next_value or nil, err
end

--- Set or clear blend override and apply it immediately.
--- @param name string
--- @param value number|nil
--- @return boolean ok
--- @return string|nil err
function M.set_blend(name, value)
  if value ~= nil then
    local number_value = tonumber(value)
    if number_value == nil then
      return false, 'Blend override must be a number or empty'
    end

    if number_value < 0 or number_value > 100 then
      return false, 'Blend override must be between 0 and 100'
    end

    value = math.floor(number_value)
  end

  override_state.ensure_runtime_group(name)
  state.runtime[name] = state.runtime[name] or {}
  state.runtime[name].blend = value

  override_state.remove_empty_runtime_entry(name)
  override_state.rebuild_active()
  apply.apply_group(name)
  return true, nil
end

--- Remove all runtime overrides for one highlight group and restore its base highlight.
--- @param name string Highlight group name
--- @return nil
function M.clear(name)
  state.runtime[name] = nil
  state.runtime_groups[name] = nil
  override_state.rebuild_active()
  apply.apply_group(name)
end

--- Persist the current runtime overrides to the configured hlcraft directory.
--- @return boolean ok
--- @return string|nil err
function M.save()
  local persisted = override_state.deepcopy(state.runtime)
  local persisted_groups = override_state.deepcopy(state.runtime_groups)
  local ok, err = storage.save(persisted, persisted_groups)
  if not ok then
    return false, err
  end

  state.persisted = persisted
  state.persisted_groups = persisted_groups
  return true, nil
end

--- Return whether a group currently has runtime overrides.
--- @param name string
--- @return boolean
function M.has_runtime(name)
  return state.runtime[name] ~= nil and next(state.runtime[name]) ~= nil
end

--- Return whether a group currently has persisted overrides.
--- @param name string
--- @return boolean
function M.has_persisted(name)
  return state.persisted[name] ~= nil and next(state.persisted[name]) ~= nil
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
  return storage.file_path(M.get_runtime_group(name))
end

return M
