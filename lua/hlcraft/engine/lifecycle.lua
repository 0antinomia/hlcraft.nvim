local M = {}

local dynamic_runtime = require('hlcraft.dynamic.runtime')
local storage = require('hlcraft.persistence.repository')
local applier = require('hlcraft.engine.applier')
local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local data = store.data

function M.bootstrap(force, replay)
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
  data.preset = applier.build_preset_overrides()
  snapshot.rebuild_active()
  data.pending = {}
  applier.refresh_base_specs()

  data.group = vim.api.nvim_create_augroup('HlcraftOverrides', { clear = true })
  applier.register_reapply_events(replay)

  data.bootstrapped = true
  replay()

  if next(data.pending) ~= nil then
    applier.install_pending_hook()
  end

  dynamic_runtime.start()
end

function M.restore_persisted(name)
  data.draft[name] = snapshot.deepcopy(data.persisted[name])
  data.draft_groups[name] = data.persisted_groups[name]
  snapshot.rebuild_active()
  applier.refresh_base_specs()
  applier.apply_group(name)
end

function M.clear(name)
  data.draft[name] = nil
  data.draft_groups[name] = nil
  snapshot.rebuild_active()
  applier.apply_group(name)
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
