--- @type table
local M = {}

local color = require('hlcraft.color')
local config = require('hlcraft.config')
local highlights = require('hlcraft.highlights')
local presets = require('hlcraft.presets')
local storage = require('hlcraft.storage')

local color_keys = { 'fg', 'bg', 'sp' }
local style_keys = {
  'bold',
  'italic',
  'underline',
  'undercurl',
  'strikethrough',
  'underdouble',
  'underdotted',
  'underdashed',
}
local numeric_keys = { 'blend' }
local override_keys = vim.list_extend(vim.list_extend(vim.deepcopy(color_keys), vim.deepcopy(style_keys)), numeric_keys)

local state = {
  applying = false,
  bootstrapped = false,
  group = nil,
  base_specs = {},
  active = {},
  preset = {},
  hooked = false,
  original_set_hl = vim.api.nvim_set_hl,
  persisted = {},
  persisted_groups = {},
  pending = {},
  runtime = {},
  runtime_groups = {},
}

local function deepcopy(value)
  return vim.deepcopy(value)
end

local install_pending_hook

local function normalized_set_hl_spec(name)
  local group = highlights.get_group(name)
  if not group then
    return {}
  end

  return {
    fg = group.resolved_fg ~= 'NONE' and group.resolved_fg or 'NONE',
    bg = group.resolved_bg ~= 'NONE' and group.resolved_bg or 'NONE',
    sp = group.sp ~= 'NONE' and group.sp or 'NONE',
    bold = group.bold or nil,
    italic = group.italic or nil,
    underline = group.underline or nil,
    undercurl = group.undercurl or nil,
    strikethrough = group.strikethrough or nil,
    underdouble = group.underdouble or nil,
    underdotted = group.underdotted or nil,
    underdashed = group.underdashed or nil,
    blend = group.blend,
  }
end

local function group_exists(name)
  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = name, create = false })
  return ok and spec and not vim.tbl_isempty(spec)
end

local function capture_group(name)
  if state.base_specs[name] ~= nil then
    return
  end

  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = name, create = false })
  if ok and spec and not vim.tbl_isempty(spec) then
    state.base_specs[name] = deepcopy(spec)
    return
  end

  state.base_specs[name] = normalized_set_hl_spec(name)
end

local function restore_group(name)
  local base = state.base_specs[name]
  if not base then
    return
  end

  vim.api.nvim_set_hl(0, name, deepcopy(base))
end

local function merged_spec(name)
  capture_group(name)

  local spec = normalized_set_hl_spec(name)
  local override = state.active[name]
  if not override then
    return spec
  end

  for _, key in ipairs(override_keys) do
    if override[key] ~= nil then
      spec[key] = override[key]
    end
  end

  return spec
end

local function build_preset_overrides()
  if not config.from_none_enabled() then
    return {}
  end

  return presets.transparent(config.from_none_scope())
end

local function rebuild_active()
  state.active = vim.tbl_deep_extend('force', deepcopy(state.preset), deepcopy(state.runtime))
end

local function ensure_runtime_group(name)
  if state.runtime_groups[name] == nil or vim.trim(tostring(state.runtime_groups[name])) == '' then
    state.runtime_groups[name] = state.persisted_groups[name] or config.default_group_name()
  end
end

local function apply_group(name)
  local override = state.active[name]
  if not override or next(override) == nil then
    state.pending[name] = nil
    restore_group(name)
    return
  end

  if not group_exists(name) then
    state.pending[name] = true
    install_pending_hook() -- ensure hook is active when pending exists
    return
  end

  state.pending[name] = nil
  state.applying = true
  local ok, err = pcall(state.original_set_hl, 0, name, merged_spec(name))
  state.applying = false

  if not ok then
    vim.notify(('hlcraft: failed to apply highlight %s: %s'):format(name, tostring(err)), vim.log.levels.WARN)
  end
end

local function refresh_base_specs()
  state.base_specs = {}
end

local function uninstall_pending_hook()
  if not state.hooked then
    return
  end

  -- Safety check (Pitfall 4): only restore if our hook is still active.
  -- Another plugin may have replaced nvim_set_hl after our install.
  -- Do NOT restore -- that would overwrite their hook.
  -- Pending groups will be resolved on next ColorScheme replay.
  if vim.api.nvim_set_hl ~= state.original_set_hl then
    state.hooked = false
    return
  end
  vim.api.nvim_set_hl = state.original_set_hl
  state.hooked = false
end

install_pending_hook = function()
  if state.hooked then
    return
  end

  vim.api.nvim_set_hl = function(ns_id, name, spec)
    state.original_set_hl(ns_id, name, spec)

    if state.applying then
      return
    end
    if ns_id ~= 0 or type(name) ~= 'string' or name == '' then
      return
    end

    -- ONLY intercept calls for groups in the pending set (D-02)
    if not state.pending[name] then
      return
    end

    state.base_specs[name] = vim.deepcopy(spec or {})
    apply_group(name)

    -- Auto-uninstall when no more pending groups (D-02/D-04)
    if next(state.pending) == nil then
      uninstall_pending_hook()
    end
  end

  state.hooked = true
end

local function register_reapply_events()
  if not config.config.reapply_events.enabled then
    return
  end

  for index, hook in ipairs(config.config.reapply_events.events or {}) do
    local event = hook
    local opts = {}

    if type(hook) == 'table' then
      event = hook.event
      opts.pattern = hook.pattern
      if hook.once ~= nil then
        opts.once = hook.once
      end
    end

    if type(event) == 'string' and event ~= '' then
      vim.api.nvim_create_autocmd(event, {
        group = state.group,
        pattern = opts.pattern,
        once = opts.once,
        callback = function()
          vim.schedule(function()
            refresh_base_specs()
            M.apply_all()
          end)
        end,
        desc = ('hlcraft replay hook %d'):format(index),
      })
    end
  end
end

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
  state.persisted = deepcopy(loaded.entries or {})
  state.persisted_groups = deepcopy(loaded.groups or {})
  state.runtime = deepcopy(state.persisted)
  state.runtime_groups = deepcopy(state.persisted_groups)
  state.preset = build_preset_overrides()
  rebuild_active()
  state.pending = {}
  refresh_base_specs()

  state.group = vim.api.nvim_create_augroup('HlcraftOverrides', { clear = true })
  register_reapply_events()

  state.bootstrapped = true
  M.apply_all()

  -- Install narrow hook only if pending groups remain after apply_all (D-04)
  if next(state.pending) ~= nil then
    install_pending_hook()
  end
end

--- Apply all active overrides to the current colorscheme.
--- @return nil
function M.apply_all()
  for name, _ in pairs(state.active) do
    apply_group(name)
  end
end

--- Return the active runtime override for a group.
--- @param name string
--- @return table
function M.get(name)
  return deepcopy(state.runtime[name] or {})
end

--- Return the persisted override for a group.
--- @param name string
--- @return table
function M.get_persisted(name)
  return deepcopy(state.persisted[name] or {})
end

--- Return the current runtime TOML section for a highlight group.
--- @param name string
--- @return string
function M.get_runtime_group(name)
  return state.runtime_groups[name] or state.persisted_groups[name] or config.default_group_name()
end

--- Return the persisted TOML section for a highlight group.
--- @param name string
--- @return string
function M.get_persisted_group(name)
  return state.persisted_groups[name] or config.default_group_name()
end

--- Set the runtime TOML section for a highlight group.
--- @param name string
--- @param group_name string|nil
--- @return boolean ok
--- @return string|nil err
function M.set_group(name, group_name)
  local normalized = vim.trim(tostring(group_name or ''))
  if normalized == '' then
    normalized = config.default_group_name()
  end

  if not state.runtime[name] then
    state.runtime[name] = {}
  end

  state.runtime_groups[name] = normalized
  rebuild_active()
  apply_group(name)
  return true, nil
end

--- Set or clear one color override field and apply it immediately.
--- @param name string
--- @param key '"fg"'|'"bg"'|'"sp"'
--- @param value string|nil
--- @return boolean ok
--- @return string|nil err
function M.set_color(name, key, value)
  if not vim.tbl_contains(color_keys, key) then
    return false, ('Unsupported override key: %s'):format(tostring(key))
  end

  local normalized, err = color.normalize(value)
  if err then
    return false, err
  end

  ensure_runtime_group(name)
  state.runtime[name] = state.runtime[name] or {}
  state.runtime[name][key] = normalized

  if state.runtime[name][key] == nil then
    state.runtime[name][key] = nil
  end

  if next(state.runtime[name]) == nil then
    state.runtime[name] = nil
    state.runtime_groups[name] = nil
  end

  rebuild_active()
  apply_group(name)
  return true, nil
end

--- Set or clear one boolean style override and apply it immediately.
--- @param name string
--- @param key string
--- @param value boolean|nil
--- @return boolean ok
--- @return string|nil err
function M.set_style(name, key, value)
  if not vim.tbl_contains(style_keys, key) then
    return false, ('Unsupported style key: %s'):format(tostring(key))
  end

  if value ~= nil and type(value) ~= 'boolean' then
    return false, ('Style override %s must be boolean or nil'):format(key)
  end

  ensure_runtime_group(name)
  state.runtime[name] = state.runtime[name] or {}
  state.runtime[name][key] = value

  if next(state.runtime[name]) == nil then
    state.runtime[name] = nil
    state.runtime_groups[name] = nil
  end

  rebuild_active()
  apply_group(name)
  return true, nil
end

--- Toggle one boolean style override against the current live highlight.
--- @param name string
--- @param key string
--- @return boolean ok
--- @return boolean|nil value
--- @return string|nil err
function M.toggle_style(name, key)
  if not vim.tbl_contains(style_keys, key) then
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

  ensure_runtime_group(name)
  state.runtime[name] = state.runtime[name] or {}
  state.runtime[name].blend = value

  if next(state.runtime[name]) == nil then
    state.runtime[name] = nil
    state.runtime_groups[name] = nil
  end

  rebuild_active()
  apply_group(name)
  return true, nil
end

--- Remove all runtime overrides for one highlight group and restore its base highlight.
--- @param name string Highlight group name
--- @return nil
function M.clear(name)
  state.runtime[name] = nil
  state.runtime_groups[name] = nil
  rebuild_active()
  apply_group(name)
end

--- Persist the current runtime overrides to the configured hlcraft directory.
--- @return boolean ok
--- @return string|nil err
function M.save()
  state.persisted = deepcopy(state.runtime)
  state.persisted_groups = deepcopy(state.runtime_groups)
  return storage.save(state.persisted, state.persisted_groups)
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
--- @return string
function M.file_path(name)
  return storage.file_path(M.get_runtime_group(name))
end

return M
