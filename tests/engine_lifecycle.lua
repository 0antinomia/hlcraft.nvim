local h = require('tests.helpers')
local scope = 'hlcraft engine lifecycle'

local lifecycle_module = 'hlcraft.engine.lifecycle'
local repository_module = 'hlcraft.persistence.repository'
local original_lifecycle = package.loaded[lifecycle_module]
local original_repository = package.loaded[repository_module]

local store = require('hlcraft.engine.store')
local original_bootstrapped = store.data.bootstrapped
local original_group = store.data.group
local original_persisted = vim.deepcopy(store.data.persisted)
local original_persisted_groups = vim.deepcopy(store.data.persisted_groups)
local original_draft = vim.deepcopy(store.data.draft)
local original_draft_groups = vim.deepcopy(store.data.draft_groups)
local original_active = vim.deepcopy(store.data.active)
local original_pending = vim.deepcopy(store.data.pending)
local original_preset = vim.deepcopy(store.data.preset)

local function restore_state()
  store.data.bootstrapped = original_bootstrapped
  store.data.group = original_group
  store.data.persisted = original_persisted
  store.data.persisted_groups = original_persisted_groups
  store.data.draft = original_draft
  store.data.draft_groups = original_draft_groups
  store.data.active = original_active
  store.data.pending = original_pending
  store.data.preset = original_preset
  package.loaded[lifecycle_module] = original_lifecycle
  package.loaded[repository_module] = original_repository
end

local function load_with_repository(fake_repository)
  package.loaded[lifecycle_module] = nil
  package.loaded[repository_module] = fake_repository
  return require(lifecycle_module)
end

local ok, err = xpcall(function()
  store.data.bootstrapped = false
  store.data.group = nil

  local invalid_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {},
      }
    end,
  })
  local invalid_load_ok = pcall(invalid_lifecycle.bootstrap, true, function() end)
  h.assert_true(not invalid_load_ok, 'lifecycle accepted incomplete loaded persistence data', scope)

  local nil_lifecycle = load_with_repository({
    load = function()
      return nil
    end,
  })
  local nil_load_ok = pcall(nil_lifecycle.bootstrap, true, function() end)
  h.assert_true(not nil_load_ok, 'lifecycle accepted nil loaded persistence data', scope)

  local missing_replay_ok = pcall(nil_lifecycle.bootstrap, true, nil)
  h.assert_true(not missing_replay_ok, 'lifecycle accepted missing replay callback', scope)
  local missing_restore_name_ok = pcall(nil_lifecycle.restore_persisted, nil)
  h.assert_true(not missing_restore_name_ok, 'lifecycle restore accepted missing highlight name', scope)
  local empty_clear_name_ok = pcall(nil_lifecycle.clear, '')
  h.assert_true(not empty_clear_name_ok, 'lifecycle clear accepted empty highlight name', scope)
end, debug.traceback)

restore_state()

if not ok then
  error(err, 0)
end

print('hlcraft engine lifecycle: OK')
