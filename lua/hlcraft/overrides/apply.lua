local config = require('hlcraft.config')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local highlights = require('hlcraft.highlights')
local presets = require('hlcraft.presets')
local override_state = require('hlcraft.overrides.state')

local M = {}

local state = override_state.data

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
    state.base_specs[name] = override_state.deepcopy(spec)
    return
  end

  state.base_specs[name] = normalized_set_hl_spec(name)
end

local function restore_group(name)
  local base = state.base_specs[name]
  if not base then
    return
  end

  vim.api.nvim_set_hl(0, name, override_state.deepcopy(base))
end

local function merged_spec(name)
  capture_group(name)

  local spec = normalized_set_hl_spec(name)
  local override = state.active[name]
  if not override then
    return spec
  end

  for _, key in ipairs(override_state.override_keys) do
    if override[key] ~= nil then
      spec[key] = override[key]
    end
  end

  return spec
end

function M.build_preset_overrides()
  if not config.from_none_enabled() then
    return {}
  end

  return presets.transparent(config.from_none_scope())
end

function M.refresh_base_specs()
  dynamic_runtime.stop()
  override_state.refresh_base_specs()
end

function M.uninstall_pending_hook()
  if not state.hooked then
    return
  end

  if vim.api.nvim_set_hl ~= state.original_set_hl then
    state.hooked = false
    return
  end
  vim.api.nvim_set_hl = state.original_set_hl
  state.hooked = false
end

function M.apply_group(name)
  local override = state.active[name]
  if not override or next(override) == nil then
    state.pending[name] = nil
    restore_group(name)
    dynamic_runtime.clear_group(name, state.base_specs[name])
    return
  end

  if not group_exists(name) then
    state.pending[name] = true
    M.install_pending_hook()
    return
  end

  state.pending[name] = nil
  local dynamic_base_spec = dynamic_runtime.base_spec(name)
  if dynamic_base_spec then
    dynamic_runtime.clear_group(name, dynamic_base_spec)
  end

  state.applying = true
  local spec = merged_spec(name)
  local ok, err = pcall(state.original_set_hl, 0, name, spec)
  state.applying = false

  if not ok then
    vim.notify(('hlcraft: failed to apply highlight %s: %s'):format(name, tostring(err)), vim.log.levels.WARN)
    return
  end

  dynamic_runtime.sync_group(name, spec, override)
end

function M.install_pending_hook()
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

    if not state.pending[name] then
      return
    end

    state.base_specs[name] = vim.deepcopy(spec or {})
    M.apply_group(name)

    if next(state.pending) == nil then
      M.uninstall_pending_hook()
    end
  end

  state.hooked = true
end

function M.apply_all()
  for name, _ in pairs(state.active) do
    M.apply_group(name)
  end
end

function M.register_reapply_events(replay)
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
            M.refresh_base_specs()
            replay()
          end)
        end,
        desc = ('hlcraft replay hook %d'):format(index),
      })
    end
  end
end

return M
