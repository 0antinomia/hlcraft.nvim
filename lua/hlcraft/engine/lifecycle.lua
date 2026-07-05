local M = {}

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

function M.bootstrap(force, replay)
  if data.bootstrapped and not force then
    return
  end
  replay = assert_replay(replay)

  if data.bootstrapped and data.group then
    pcall(vim.api.nvim_del_augroup_by_id, data.group)
  end

  local loaded = assert_loaded_data(storage.load())
  data.persisted = snapshot.deepcopy(loaded.entries)
  data.persisted_groups = snapshot.deepcopy(loaded.groups)
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
  name = assert_name(name)
  data.draft[name] = snapshot.deepcopy(data.persisted[name])
  data.draft_groups[name] = data.persisted_groups[name]
  snapshot.rebuild_active()
  applier.refresh_base_specs()
  applier.apply_group(name)
end

function M.clear(name)
  name = assert_name(name)
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
