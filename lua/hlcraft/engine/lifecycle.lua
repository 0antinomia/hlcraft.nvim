local M = {}

local base_specs = require('hlcraft.engine.base_specs')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local storage = require('hlcraft.persistence.repository')
local applier = require('hlcraft.engine.applier')
local highlight_names = require('hlcraft.core.highlight_names')
local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local data = store.data

local function assert_name(name)
  return highlight_names.assert(name, 'highlight name', 3)
end

local function assert_replay(replay)
  if type(replay) ~= 'function' then
    error('engine lifecycle requires a replay callback', 3)
  end
  return replay
end

local function assert_loaded_data(loaded)
  if type(loaded) ~= 'table' then
    error('loaded persistence data must be a table', 3)
  end
  for _, key in ipairs({ 'entries', 'groups' }) do
    if type(loaded[key]) ~= 'table' then
      error(('loaded persistence %s must be a table'):format(key), 3)
    end
  end
  return loaded
end

local function autocmd_group_exists(group)
  return type(group) == 'number' and pcall(vim.api.nvim_get_autocmds, { group = group })
end

local function apply_group_or_error(name)
  local applied, err = applier.apply_group(name)
  if applied == false then
    error(err or 'failed to apply highlight', 2)
  end
end

local function snapshot_bootstrap_data()
  return {
    active = snapshot.deepcopy(data.active),
    base_specs = snapshot.deepcopy(data.base_specs),
    bootstrapped = data.bootstrapped,
    draft = snapshot.deepcopy(data.draft),
    draft_groups = snapshot.deepcopy(data.draft_groups),
    dynamic_runtime = dynamic_runtime.capture(),
    hooked = data.hooked,
    pending = snapshot.deepcopy(data.pending),
    persisted = snapshot.deepcopy(data.persisted),
    persisted_groups = snapshot.deepcopy(data.persisted_groups),
    preset = snapshot.deepcopy(data.preset),
  }
end

local function restore_bootstrap_data(previous)
  if previous == nil then
    return
  end
  data.active = previous.active
  data.base_specs = previous.base_specs
  data.draft = previous.draft
  data.draft_groups = previous.draft_groups
  data.pending = previous.pending
  data.persisted = previous.persisted
  data.persisted_groups = previous.persisted_groups
  data.preset = previous.preset
end

local function restore_bootstrap_resources(previous, replay)
  data.hooked = false
  dynamic_runtime.restore(previous.dynamic_runtime)
  if not previous.bootstrapped then
    snapshot.refresh_base_specs()
    data.group = nil
    data.pending = {}
    data.bootstrapped = false
    return
  end

  data.group = vim.api.nvim_create_augroup('HlcraftOverrides', { clear = true })
  applier.register_reapply_events(replay)
  if previous.hooked and next(data.pending) ~= nil then
    applier.install_pending_hook()
  end
  data.bootstrapped = true
end

local function rollback_bootstrap(previous, replay)
  applier.uninstall_pending_hook()
  dynamic_runtime.stop()
  local rollback_errors = {}
  for name in pairs(data.base_specs) do
    local restored, restore_err = pcall(base_specs.restore, data, name)
    if not restored then
      rollback_errors[#rollback_errors + 1] = ('failed to restore base highlight %s: %s'):format(
        name,
        tostring(restore_err)
      )
    end
  end
  local rollback_group = data.group
  if rollback_group then
    local deleted, delete_err = pcall(vim.api.nvim_del_augroup_by_id, rollback_group)
    if not deleted and autocmd_group_exists(rollback_group) then
      rollback_errors[#rollback_errors + 1] = tostring(delete_err)
    end
  end
  restore_bootstrap_data(previous)
  local restored, restore_err = xpcall(function()
    restore_bootstrap_resources(previous, replay)
  end, debug.traceback)
  if not restored then
    rollback_errors[#rollback_errors + 1] = tostring(restore_err)
  end
  if #rollback_errors > 0 then
    if data.group == nil and autocmd_group_exists(rollback_group) then
      data.group = rollback_group
    end
    error(table.concat(rollback_errors, '; '), 0)
  end
end

local function append_rollback_error(err, rollback_err)
  if rollback_err == nil then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, tostring(rollback_err))
end

function M.bootstrap(force, replay)
  if data.bootstrapped and not force then
    return
  end
  replay = assert_replay(replay)

  local previous_data = snapshot_bootstrap_data()
  local loaded = assert_loaded_data(storage.load())

  applier.uninstall_pending_hook()
  if data.bootstrapped and data.group then
    pcall(vim.api.nvim_del_augroup_by_id, data.group)
  end

  data.persisted = snapshot.deepcopy(loaded.entries)
  data.persisted_groups = snapshot.deepcopy(loaded.groups)
  data.draft = snapshot.deepcopy(data.persisted)
  data.draft_groups = snapshot.deepcopy(data.persisted_groups)
  data.preset = applier.build_preset_overrides()
  snapshot.rebuild_active()
  data.pending = {}

  local ok, err = xpcall(function()
    applier.refresh_base_specs()
    data.group = vim.api.nvim_create_augroup('HlcraftOverrides', { clear = true })
    applier.register_reapply_events(replay)
    replay()

    if next(data.pending) ~= nil then
      applier.install_pending_hook()
    end

    dynamic_runtime.start()
  end, debug.traceback)
  if not ok then
    local rolled_back, rollback_err = xpcall(function()
      rollback_bootstrap(previous_data, replay)
    end, debug.traceback)
    if not rolled_back then
      error(append_rollback_error(err, rollback_err), 0)
    end
    error(err, 0)
  end

  data.bootstrapped = true
end

function M.restore_persisted(name)
  name = assert_name(name)
  local previous = snapshot.capture_apply_data()
  data.draft[name] = snapshot.deepcopy(data.persisted[name])
  data.draft_groups[name] = data.persisted_groups[name]
  snapshot.rebuild_active()
  local ok, err = xpcall(function()
    apply_group_or_error(name)
  end, debug.traceback)
  if not ok then
    snapshot.restore_apply_data(previous)
    error(err, 0)
  end
end

function M.clear(name)
  name = assert_name(name)
  local previous = snapshot.capture_apply_data()
  data.draft[name] = nil
  data.draft_groups[name] = nil
  snapshot.rebuild_active()
  local ok, err = xpcall(function()
    apply_group_or_error(name)
  end, debug.traceback)
  if not ok then
    snapshot.restore_apply_data(previous)
    error(err, 0)
  end
end

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

function M.path()
  return storage.path()
end

function M.file_path(group_name)
  return storage.file_path(group_name)
end

return M
