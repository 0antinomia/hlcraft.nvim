local base_specs = require('hlcraft.engine.base_specs')
local config = require('hlcraft.config')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local notify = require('hlcraft.notify')
local presets = require('hlcraft.core.presets')
local highlight_names = require('hlcraft.core.highlight_names')
local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')
local tables = require('hlcraft.core.tables')

local M = {}

local state = store.data
local pending_hook = nil
local reapply_generation = 0

local function assert_table(value, label)
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  return value
end

local function assert_name(name)
  return highlight_names.assert(name, 'highlight name', 3)
end

local function assert_replay(replay)
  if type(replay) ~= 'function' then
    error('engine applier requires a replay callback', 3)
  end
  return replay
end

local function refresh_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error('engine applier refresh options must be a table', 3)
  end
  for key in pairs(opts) do
    if key ~= 'restore_dynamic' then
      error(('unknown engine applier refresh option: %s'):format(tostring(key)), 3)
    end
  end
  if opts.restore_dynamic ~= nil and type(opts.restore_dynamic) ~= 'boolean' then
    error('engine applier refresh restore_dynamic option must be boolean', 3)
  end
  return opts
end

local function capture_live_spec(name)
  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = name, create = false })
  if not ok then
    error(('failed to capture live highlight %s: %s'):format(name, tostring(spec)), 2)
  end
  return snapshot.deepcopy(spec or {})
end

local function capture_live_specs(tasks)
  local captured = {}
  for name in pairs(tasks) do
    captured[name] = capture_live_spec(name)
  end
  return captured
end

local function restore_live_spec(name, spec)
  local applying = state.applying
  state.applying = true
  local ok, err = pcall(function()
    state.original_set_hl(0, name, snapshot.deepcopy(spec or {}))
  end)
  state.applying = applying
  if not ok then
    return false, ('failed to restore live highlight %s: %s'):format(name, tostring(err))
  end
  return true, nil
end

local function restore_live_specs(captured)
  local errors = {}
  for name, spec in pairs(captured) do
    local ok, err = restore_live_spec(name, spec)
    if not ok then
      errors[#errors + 1] = err
    end
  end
  if #errors > 0 then
    return false, table.concat(errors, '; ')
  end
  return true, nil
end

local function restore_dynamic_and_live(dynamic_snapshot, live_snapshot)
  local errors = {}
  local dynamic_ok, dynamic_err = xpcall(function()
    dynamic_runtime.restore(dynamic_snapshot)
  end, debug.traceback)
  if not dynamic_ok then
    errors[#errors + 1] = tostring(dynamic_err)
  end

  local live_ok, live_err = restore_live_specs(live_snapshot)
  if not live_ok then
    errors[#errors + 1] = live_err
  end

  if #errors > 0 then
    return false, table.concat(errors, '; ')
  end
  return true, nil
end

local function append_rollback_error(err, rollback_err)
  if not rollback_err then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, rollback_err)
end

function M.build_preset_overrides()
  if not config.transparent_enabled() then
    return {}
  end

  return presets.transparent(config.transparent_scope())
end

function M.refresh_base_specs(opts)
  opts = refresh_opts(opts)
  if opts.restore_dynamic == false then
    dynamic_runtime.reset()
  else
    local dynamic_snapshot = dynamic_runtime.capture()
    local live_snapshot = capture_live_specs(dynamic_snapshot.tasks)
    if not dynamic_runtime.stop() then
      local restored, restore_err = restore_dynamic_and_live(dynamic_snapshot, live_snapshot)
      local err = 'failed to restore dynamic highlights before refreshing base specs'
      error(append_rollback_error(err, restored and nil or restore_err), 2)
    end
  end
  snapshot.refresh_base_specs()
end

function M.uninstall_pending_hook()
  if not state.hooked then
    return
  end

  if vim.api.nvim_set_hl == pending_hook then
    vim.api.nvim_set_hl = state.original_set_hl
  end
  pending_hook = nil
  state.hooked = false
end

function M.apply_group(name)
  name = assert_name(name)
  local override = state.active[name]
  local live_snapshot = {
    [name] = capture_live_spec(name),
  }
  if not override or next(override) == nil then
    state.pending[name] = nil
    local dynamic_snapshot = dynamic_runtime.capture()
    base_specs.restore(state, name)
    local cleared = dynamic_runtime.clear_group(name, state.base_specs[name])
    if not cleared then
      local err = ('failed to restore dynamic highlight %s before clear'):format(name)
      local restored, restore_err = restore_dynamic_and_live(dynamic_snapshot, live_snapshot)
      err = append_rollback_error(err, restored and nil or restore_err)
      notify.warn(err)
      return false, err
    end
    return true, nil
  end

  if not base_specs.group_exists(name) then
    state.pending[name] = true
    M.install_pending_hook()
    return true, nil
  end

  state.pending[name] = nil
  local dynamic_snapshot = dynamic_runtime.capture()
  local dynamic_base_spec = dynamic_runtime.base_spec(name)
  if dynamic_base_spec then
    local cleared = dynamic_runtime.clear_group(name, dynamic_base_spec)
    if not cleared then
      local err = ('failed to restore dynamic highlight %s before reapply'):format(name)
      local restored, restore_err = restore_dynamic_and_live(dynamic_snapshot, live_snapshot)
      err = append_rollback_error(err, restored and nil or restore_err)
      notify.warn(err)
      return false, err
    end
  end

  local spec_ok, spec = xpcall(function()
    return base_specs.merged(state, name)
  end, debug.traceback)
  if not spec_ok then
    local restored, restore_err = restore_dynamic_and_live(dynamic_snapshot, live_snapshot)
    if not restored then
      error(append_rollback_error(spec, restore_err), 0)
    end
    error(spec, 0)
  end
  local applying = state.applying
  state.applying = true
  local ok, err = pcall(state.original_set_hl, 0, name, spec)
  state.applying = applying

  if not ok then
    local apply_err = ('failed to apply highlight %s: %s'):format(name, tostring(err))
    local restored, restore_err = restore_dynamic_and_live(dynamic_snapshot, live_snapshot)
    apply_err = append_rollback_error(apply_err, restored and nil or restore_err)
    notify.warn(apply_err)
    return false, apply_err
  end

  local sync_ok, sync_err = xpcall(function()
    dynamic_runtime.sync_group(name, spec, override)
  end, debug.traceback)
  if not sync_ok then
    local restored, restore_err = restore_dynamic_and_live(dynamic_snapshot, live_snapshot)
    if not restored then
      error(append_rollback_error(sync_err, restore_err), 0)
    end
    error(sync_err, 0)
  end
  return true, nil
end

function M.install_pending_hook()
  if state.hooked then
    return
  end

  pending_hook = function(ns_id, name, spec)
    state.original_set_hl(ns_id, name, spec)

    if state.applying then
      return
    end
    if ns_id ~= 0 or not highlight_names.validate(name, 'highlight name') then
      return
    end

    if not state.pending[name] then
      return
    end

    state.base_specs[name] = vim.deepcopy(assert_table(spec, 'pending highlight spec'))
    local applied
    local apply_ok, apply_err = xpcall(function()
      applied = M.apply_group(name)
    end, debug.traceback)
    if not apply_ok then
      state.pending[name] = true
      notify.warn(('pending highlight apply failed: %s'):format(tostring(apply_err)))
      return
    end
    if applied == false then
      state.pending[name] = true
      return
    end

    if next(state.pending) == nil then
      M.uninstall_pending_hook()
    end
  end

  vim.api.nvim_set_hl = pending_hook
  state.hooked = true
end

function M.apply_all()
  for name, _ in pairs(state.active) do
    local applied, err = M.apply_group(name)
    if applied == false then
      error(err or ('failed to apply highlight %s'):format(name), 2)
    end
  end
end

local function run_reapply_hook(replay)
  local ok, err = xpcall(function()
    M.refresh_base_specs({ restore_dynamic = false })
    replay()
  end, debug.traceback)
  if not ok then
    notify.warn(('highlight reapply hook failed: %s'):format(tostring(err)))
  end
end

function M.register_reapply_events(replay)
  reapply_generation = reapply_generation + 1
  local registered_generation = reapply_generation
  local reapply_events = config.config.persistence.reapply_events
  if not reapply_events.enabled then
    return
  end
  replay = assert_replay(replay)
  local registered_group = state.group

  for index, hook in ipairs(tables.assert_sequence(reapply_events.events, 'reapply events', 3)) do
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
            if state.group ~= registered_group or reapply_generation ~= registered_generation then
              return
            end
            run_reapply_hook(replay)
          end)
        end,
        desc = ('hlcraft replay hook %d'):format(index),
      })
    end
  end
end

return M
