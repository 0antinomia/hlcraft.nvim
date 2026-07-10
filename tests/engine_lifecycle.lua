local h = require('tests.helpers')
local scope = 'hlcraft engine lifecycle'

local lifecycle_module = 'hlcraft.engine.lifecycle'
local repository_module = 'hlcraft.persistence.repository'
local original_lifecycle = package.loaded[lifecycle_module]
local original_repository = package.loaded[repository_module]

local applier = require('hlcraft.engine.applier')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local store = require('hlcraft.engine.store')
local timers = require('hlcraft.core.timers')
local original_set_hl = vim.api.nvim_set_hl
local original_store_set_hl = store.data.original_set_hl
local original_bootstrapped = store.data.bootstrapped
local original_group = store.data.group
local original_hooked = store.data.hooked
local original_persisted = vim.deepcopy(store.data.persisted)
local original_persisted_groups = vim.deepcopy(store.data.persisted_groups)
local original_draft = vim.deepcopy(store.data.draft)
local original_draft_groups = vim.deepcopy(store.data.draft_groups)
local original_active = vim.deepcopy(store.data.active)
local original_pending = vim.deepcopy(store.data.pending)
local original_base_specs = vim.deepcopy(store.data.base_specs)
local original_dynamic_runtime = dynamic_runtime.capture()
local original_preset = vim.deepcopy(store.data.preset)

local function restore_state()
  if store.data.group and store.data.group ~= original_group then
    pcall(vim.api.nvim_del_augroup_by_id, store.data.group)
  end
  if vim.api.nvim_set_hl ~= original_set_hl then
    vim.api.nvim_set_hl = original_set_hl
  end
  store.data.original_set_hl = original_store_set_hl
  store.data.bootstrapped = original_bootstrapped
  store.data.group = original_group
  store.data.hooked = original_hooked
  store.data.persisted = original_persisted
  store.data.persisted_groups = original_persisted_groups
  store.data.draft = original_draft
  store.data.draft_groups = original_draft_groups
  store.data.active = original_active
  store.data.pending = original_pending
  store.data.base_specs = original_base_specs
  dynamic_runtime.restore(original_dynamic_runtime)
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

  local replay_failure_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {
          HlcraftEngineLifecycleLoadedReplay = {
            fg = '#333333',
          },
        },
        groups = {
          HlcraftEngineLifecycleLoadedReplay = 'loaded',
        },
      }
    end,
  })
  store.data.persisted = {
    HlcraftEngineLifecycleOldReplay = {
      fg = '#101010',
    },
  }
  store.data.persisted_groups = {
    HlcraftEngineLifecycleOldReplay = 'old',
  }
  store.data.draft = vim.deepcopy(store.data.persisted)
  store.data.draft_groups = vim.deepcopy(store.data.persisted_groups)
  store.data.active = vim.deepcopy(store.data.draft)
  store.data.preset = {
    HlcraftEngineLifecycleOldPreset = {
      bg = '#202020',
    },
  }
  local applied_replay_name = 'HlcraftEngineLifecycleAppliedReplay'
  vim.api.nvim_set_hl(0, applied_replay_name, { fg = '#111111' })
  local replay_failure_ok = pcall(replay_failure_lifecycle.bootstrap, true, function()
    store.data.active = {
      [applied_replay_name] = {
        fg = '#222222',
      },
      HlcraftEngineLifecyclePendingReplay = {
        fg = '#222222',
      },
    }
    applier.apply_group(applied_replay_name)
    applier.apply_group('HlcraftEngineLifecyclePendingReplay')
    error('replay failed')
  end)
  local replay_failure_hl = vim.api.nvim_get_hl(0, { name = applied_replay_name, create = false })
  h.assert_true(not replay_failure_ok, 'lifecycle accepted failed bootstrap replay', scope)
  h.assert_equal(replay_failure_hl.fg, 0x111111, 'lifecycle kept applied highlight after failed replay', scope)
  h.assert_true(not store.data.bootstrapped, 'lifecycle kept bootstrapped state after failed replay', scope)
  h.assert_true(store.data.group == nil, 'lifecycle kept augroup state after failed replay', scope)
  h.assert_true(next(store.data.base_specs) == nil, 'lifecycle kept base specs after failed replay', scope)
  h.assert_true(
    store.data.persisted.HlcraftEngineLifecycleOldReplay ~= nil,
    'lifecycle changed persisted entries after failed replay',
    scope
  )
  h.assert_true(
    store.data.draft.HlcraftEngineLifecycleOldReplay ~= nil,
    'lifecycle changed draft entries after failed replay',
    scope
  )
  h.assert_true(
    store.data.active.HlcraftEngineLifecycleOldReplay ~= nil,
    'lifecycle changed active entries after failed replay',
    scope
  )
  h.assert_true(
    store.data.preset.HlcraftEngineLifecycleOldPreset ~= nil,
    'lifecycle changed preset entries after failed replay',
    scope
  )
  h.assert_true(next(store.data.pending) == nil, 'lifecycle kept pending highlights after failed replay', scope)
  h.assert_true(not store.data.hooked, 'lifecycle kept pending hook state after failed replay', scope)

  local group_delete_failure_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {},
        groups = {},
      }
    end,
  })
  store.data.bootstrapped = false
  store.data.group = nil
  local group_delete_failure_group
  local original_del_augroup = vim.api.nvim_del_augroup_by_id
  vim.api.nvim_del_augroup_by_id = function(group, ...)
    if group_delete_failure_group ~= nil and group == group_delete_failure_group then
      error('bootstrap group delete failed')
    end
    return original_del_augroup(group, ...)
  end
  local group_delete_failure_ok, group_delete_failure_err = pcall(
    group_delete_failure_lifecycle.bootstrap,
    true,
    function()
      group_delete_failure_group = store.data.group
      error('bootstrap replay failed')
    end
  )
  vim.api.nvim_del_augroup_by_id = original_del_augroup
  local group_delete_failure_kept_group = store.data.group
  local group_delete_failure_group_exists = group_delete_failure_group ~= nil
    and pcall(vim.api.nvim_get_autocmds, { group = group_delete_failure_group })
  if group_delete_failure_group_exists then
    vim.api.nvim_del_augroup_by_id(group_delete_failure_group)
  end
  store.data.group = nil
  h.assert_true(not group_delete_failure_ok, 'lifecycle accepted failed replay with failed group rollback', scope)
  h.assert_true(group_delete_failure_group_exists, 'group rollback failure test did not preserve an augroup', scope)
  h.assert_equal(
    group_delete_failure_kept_group,
    group_delete_failure_group,
    'failed bootstrap group rollback dropped the live augroup handle',
    scope
  )
  h.assert_true(
    tostring(group_delete_failure_err):find('bootstrap group delete failed', 1, true) ~= nil,
    'failed bootstrap group rollback did not report the cleanup error',
    scope
  )

  local base_restore_failure_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {},
        groups = {},
      }
    end,
  })
  local base_restore_failure_name = 'HlcraftEngineLifecycleBaseRestoreFailure'
  vim.api.nvim_set_hl(0, base_restore_failure_name, { fg = '#111111' })
  local base_restore_failure_ok, base_restore_failure_err = pcall(
    base_restore_failure_lifecycle.bootstrap,
    true,
    function()
      store.data.active = {
        [base_restore_failure_name] = {
          fg = '#222222',
        },
      }
      applier.apply_group(base_restore_failure_name)
      vim.api.nvim_set_hl = function(ns, name, spec)
        if name == base_restore_failure_name then
          error('base highlight restore failed')
        end
        return original_set_hl(ns, name, spec)
      end
      error('bootstrap replay failed')
    end
  )
  vim.api.nvim_set_hl = original_set_hl
  vim.api.nvim_set_hl(0, base_restore_failure_name, { fg = '#111111' })
  h.assert_true(not base_restore_failure_ok, 'lifecycle accepted failed base highlight rollback', scope)
  h.assert_true(
    tostring(base_restore_failure_err):find('bootstrap replay failed', 1, true) ~= nil,
    'base highlight rollback failure dropped the original replay error',
    scope
  )
  h.assert_true(
    tostring(base_restore_failure_err):find('base highlight restore failed', 1, true) ~= nil,
    'failed bootstrap base highlight rollback did not report the restore error',
    scope
  )

  local apply_all_failure_name = 'HlcraftEngineLifecycleApplyAllFailure'
  vim.api.nvim_set_hl(0, apply_all_failure_name, { fg = '#101010' })
  local apply_all_failure_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {
          [apply_all_failure_name] = {
            fg = '#222222',
          },
        },
        groups = {
          [apply_all_failure_name] = 'apply-all',
        },
      }
    end,
  })
  store.data.original_set_hl = function()
    error('set failed')
  end
  local apply_all_failure_ok = h.with_notify_stub(function()
    return pcall(apply_all_failure_lifecycle.bootstrap, true, function()
      applier.apply_all()
    end)
  end)
  store.data.original_set_hl = original_store_set_hl
  local apply_all_failure_hl = vim.api.nvim_get_hl(0, { name = apply_all_failure_name, create = false })
  h.assert_true(not apply_all_failure_ok, 'lifecycle accepted failed apply_all replay', scope)
  h.assert_equal(apply_all_failure_hl.fg, 0x101010, 'failed apply_all replay changed highlight', scope)
  h.assert_true(not store.data.bootstrapped, 'failed apply_all replay kept bootstrapped state', scope)
  h.assert_true(store.data.group == nil, 'failed apply_all replay kept augroup state', scope)

  local dynamic_replay_failure_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {},
        groups = {},
      }
    end,
  })
  local dynamic_replay_failure_name = 'HlcraftEngineLifecycleDynamicReplayFailure'
  vim.api.nvim_set_hl(0, dynamic_replay_failure_name, { fg = '#101010' })
  local dynamic_replay_failure_ok = pcall(dynamic_replay_failure_lifecycle.bootstrap, true, function()
    store.data.active = {
      [dynamic_replay_failure_name] = {
        dynamic = {
          fg = {
            version = 1,
            duration = 1000,
            loop = 'repeat',
            timeline = {
              { at = 0, color = 'base' },
              { at = 1, color = '#ffffff' },
            },
          },
        },
      },
    }
    applier.apply_group(dynamic_replay_failure_name)
    store.data.original_set_hl = function()
      error('restore failed')
    end
    error('dynamic replay failed')
  end)
  store.data.original_set_hl = original_store_set_hl
  h.assert_true(not dynamic_replay_failure_ok, 'lifecycle accepted failed dynamic bootstrap replay', scope)
  h.assert_true(
    dynamic_runtime.base_spec(dynamic_replay_failure_name) == nil,
    'failed dynamic bootstrap rollback kept runtime task',
    scope
  )

  local rollback_runtime_failure_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {},
        groups = {},
      }
    end,
  })
  local rollback_runtime_failure_name = 'HlcraftEngineLifecycleRollbackRuntimeFailure'
  vim.api.nvim_set_hl(0, rollback_runtime_failure_name, { fg = '#101010' })
  dynamic_runtime.sync_group(rollback_runtime_failure_name, { fg = '#101010' }, {
    dynamic = {
      fg = {
        version = 1,
        duration = 1000,
        loop = 'repeat',
        timeline = {
          { at = 0, color = 'base' },
          { at = 1, color = '#ffffff' },
        },
      },
    },
  })
  local original_repeating = timers.repeating
  timers.repeating = function()
    return nil
  end
  local rollback_runtime_failure_ok, rollback_runtime_failure_err = pcall(
    rollback_runtime_failure_lifecycle.bootstrap,
    true,
    function()
      error('bootstrap replay failed')
    end
  )
  timers.repeating = original_repeating
  dynamic_runtime.clear_group(rollback_runtime_failure_name, { fg = '#101010' })
  h.assert_true(not rollback_runtime_failure_ok, 'lifecycle accepted failed bootstrap with failed rollback', scope)
  h.assert_true(
    tostring(rollback_runtime_failure_err):find('bootstrap replay failed', 1, true) ~= nil,
    'lifecycle bootstrap rollback failure dropped original error',
    scope
  )
  h.assert_true(
    tostring(rollback_runtime_failure_err):find('dynamic runtime failed to restore timer', 1, true) ~= nil,
    'lifecycle bootstrap rollback failure did not report runtime restore error',
    scope
  )

  local force_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {},
        groups = {},
      }
    end,
  })
  force_lifecycle.bootstrap(true, function()
    store.data.active = {
      HlcraftEngineLifecyclePendingForce = {
        fg = '#222222',
      },
    }
    applier.apply_group('HlcraftEngineLifecyclePendingForce')
  end)
  h.assert_true(store.data.hooked, 'lifecycle did not install pending hook for missing highlight', scope)
  h.assert_true(vim.api.nvim_set_hl ~= original_set_hl, 'pending hook did not replace nvim_set_hl', scope)
  local preserved_group = store.data.group
  local preserved_hook = vim.api.nvim_set_hl
  local load_failure_lifecycle = load_with_repository({
    load = function()
      return nil
    end,
  })
  local load_failure_ok = pcall(load_failure_lifecycle.bootstrap, true, function() end)
  local group_still_valid = pcall(vim.api.nvim_get_autocmds, { group = preserved_group })
  h.assert_true(not load_failure_ok, 'lifecycle accepted failed force bootstrap load', scope)
  h.assert_true(store.data.bootstrapped, 'failed force bootstrap load cleared bootstrapped state', scope)
  h.assert_true(group_still_valid, 'failed force bootstrap load deleted the existing augroup', scope)
  h.assert_true(store.data.hooked, 'failed force bootstrap load uninstalled pending hook state', scope)
  h.assert_true(
    vim.api.nvim_set_hl == preserved_hook,
    'failed force bootstrap load uninstalled pending hook function',
    scope
  )
  local before_force_replay_pending = vim.deepcopy(store.data.pending)
  local before_force_replay_active = vim.deepcopy(store.data.active)
  local force_replay_failure_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {
          HlcraftEngineLifecycleForceReplay = {
            fg = '#333333',
          },
        },
        groups = {
          HlcraftEngineLifecycleForceReplay = 'force-replay',
        },
      }
    end,
  })
  local force_replay_failure_ok = pcall(force_replay_failure_lifecycle.bootstrap, true, function()
    applier.apply_all()
    error('force replay failed')
  end)
  local force_replay_group_valid = type(store.data.group) == 'number'
    and pcall(vim.api.nvim_get_autocmds, { group = store.data.group })
  h.assert_true(not force_replay_failure_ok, 'lifecycle accepted failed force bootstrap replay', scope)
  h.assert_true(store.data.bootstrapped, 'failed force bootstrap replay cleared bootstrapped state', scope)
  h.assert_true(force_replay_group_valid, 'failed force bootstrap replay deleted the active augroup', scope)
  h.assert_true(store.data.hooked, 'failed force bootstrap replay uninstalled pending hook state', scope)
  h.assert_true(
    vim.api.nvim_set_hl ~= original_set_hl,
    'failed force bootstrap replay uninstalled pending hook function',
    scope
  )
  h.assert_true(
    vim.deep_equal(store.data.pending, before_force_replay_pending),
    'failed force bootstrap replay changed pending highlights',
    scope
  )
  h.assert_true(
    vim.deep_equal(store.data.active, before_force_replay_active),
    'failed force bootstrap replay changed active state',
    scope
  )

  force_lifecycle.bootstrap(true, function() end)
  h.assert_true(not store.data.hooked, 'lifecycle kept stale pending hook after force bootstrap', scope)
  h.assert_true(
    vim.api.nvim_set_hl == original_set_hl,
    'lifecycle kept stale nvim_set_hl hook after force bootstrap',
    scope
  )

  local clear_failure_lifecycle = load_with_repository({
    load = function()
      return {
        entries = {},
        groups = {},
      }
    end,
  })
  local clear_failure_name = 'HlcraftEngineLifecycleClearFailure'
  vim.api.nvim_set_hl(0, clear_failure_name, { fg = '#101010' })
  store.data.draft = {
    [clear_failure_name] = {
      fg = '#111111',
    },
  }
  store.data.draft_groups = {
    [clear_failure_name] = 'old',
  }
  store.data.preset = {}
  store.data.active = vim.deepcopy(store.data.draft)
  store.data.base_specs = {
    [clear_failure_name] = false,
  }
  local clear_before_draft = vim.deepcopy(store.data.draft)
  local clear_before_draft_groups = vim.deepcopy(store.data.draft_groups)
  local clear_before_active = vim.deepcopy(store.data.active)
  local clear_ok = pcall(clear_failure_lifecycle.clear, clear_failure_name)
  h.assert_true(not clear_ok, 'lifecycle accepted failed clear apply', scope)
  h.assert_true(vim.deep_equal(store.data.draft, clear_before_draft), 'failed clear changed draft state', scope)
  h.assert_true(
    vim.deep_equal(store.data.draft_groups, clear_before_draft_groups),
    'failed clear changed draft group state',
    scope
  )
  h.assert_true(vim.deep_equal(store.data.active, clear_before_active), 'failed clear changed active state', scope)

  local clear_dynamic_failure_name = 'HlcraftEngineLifecycleClearDynamicFailure'
  vim.api.nvim_set_hl(0, clear_dynamic_failure_name, { fg = '#111111' })
  store.data.draft = {
    [clear_dynamic_failure_name] = {
      fg = '#111111',
    },
  }
  store.data.draft_groups = {
    [clear_dynamic_failure_name] = 'old',
  }
  store.data.preset = {}
  store.data.active = vim.deepcopy(store.data.draft)
  store.data.base_specs = {
    [clear_dynamic_failure_name] = {
      fg = '#101010',
    },
  }
  store.data.pending = {}
  dynamic_runtime.sync_group(clear_dynamic_failure_name, { fg = '#101010' }, {
    dynamic = {
      fg = {
        version = 1,
        duration = 1000,
        loop = 'repeat',
        timeline = {
          { at = 0, color = 'base' },
          { at = 1, color = '#ffffff' },
        },
      },
    },
  })
  local clear_dynamic_before_draft = vim.deepcopy(store.data.draft)
  local clear_dynamic_before_draft_groups = vim.deepcopy(store.data.draft_groups)
  local clear_dynamic_before_active = vim.deepcopy(store.data.active)
  store.data.original_set_hl = function(_, applied_name, spec)
    if applied_name == clear_dynamic_failure_name and spec and spec.fg == '#101010' then
      error('dynamic clear failed')
    end
    return original_store_set_hl(0, applied_name, spec)
  end
  local clear_dynamic_ok = h.with_notify_stub(function()
    return pcall(clear_failure_lifecycle.clear, clear_dynamic_failure_name)
  end)
  store.data.original_set_hl = original_store_set_hl
  h.assert_true(not clear_dynamic_ok, 'lifecycle accepted failed dynamic clear', scope)
  h.assert_true(
    vim.deep_equal(store.data.draft, clear_dynamic_before_draft),
    'failed dynamic clear changed draft state',
    scope
  )
  h.assert_true(
    vim.deep_equal(store.data.draft_groups, clear_dynamic_before_draft_groups),
    'failed dynamic clear changed draft group state',
    scope
  )
  h.assert_true(
    vim.deep_equal(store.data.active, clear_dynamic_before_active),
    'failed dynamic clear changed active state',
    scope
  )
  local clear_dynamic_hl = vim.api.nvim_get_hl(0, { name = clear_dynamic_failure_name, create = false })
  h.assert_equal(clear_dynamic_hl.fg, 0x111111, 'failed dynamic clear kept base highlight live', scope)
  h.assert_equal(
    dynamic_runtime.base_spec(clear_dynamic_failure_name).fg,
    '#101010',
    'failed dynamic clear dropped runtime task',
    scope
  )
  dynamic_runtime.clear_group(clear_dynamic_failure_name, { fg = '#101010' })

  local restore_persisted_name = 'HlcraftEngineLifecycleRestorePersisted'
  local restore_persisted_dynamic_name = 'HlcraftEngineLifecycleRestorePersistedDynamic'
  vim.api.nvim_set_hl(0, restore_persisted_name, { fg = '#303030' })
  vim.api.nvim_set_hl(0, restore_persisted_dynamic_name, { fg = '#101010' })
  store.data.persisted = {
    [restore_persisted_name] = {
      fg = '#404040',
    },
  }
  store.data.persisted_groups = {
    [restore_persisted_name] = 'persisted',
  }
  store.data.draft = {
    [restore_persisted_name] = {
      fg = '#505050',
    },
  }
  store.data.draft_groups = {
    [restore_persisted_name] = 'draft',
  }
  store.data.preset = {}
  store.data.active = vim.deepcopy(store.data.draft)
  store.data.base_specs = {}
  store.data.pending = {}
  dynamic_runtime.sync_group(restore_persisted_dynamic_name, { fg = '#101010' }, {
    dynamic = {
      fg = {
        version = 1,
        duration = 1000,
        loop = 'repeat',
        timeline = {
          { at = 0, color = 'base' },
          { at = 1, color = '#ffffff' },
        },
      },
    },
  })
  dynamic_runtime.tick(500)
  local restore_persisted_dynamic_before =
    vim.api.nvim_get_hl(0, { name = restore_persisted_dynamic_name, create = false })
  local restore_persisted_ok = pcall(clear_failure_lifecycle.restore_persisted, restore_persisted_name)
  local restore_persisted_dynamic_task = dynamic_runtime.base_spec(restore_persisted_dynamic_name)
  local restore_persisted_dynamic_after =
    vim.api.nvim_get_hl(0, { name = restore_persisted_dynamic_name, create = false })
  dynamic_runtime.clear_group(restore_persisted_dynamic_name, { fg = '#101010' })
  vim.api.nvim_set_hl(0, restore_persisted_dynamic_name, { fg = '#101010' })
  h.assert_true(restore_persisted_ok, 'lifecycle failed to restore a persisted highlight', scope)
  h.assert_true(
    restore_persisted_dynamic_task ~= nil,
    'restoring a persisted highlight dropped an unrelated dynamic task',
    scope
  )
  h.assert_equal(
    restore_persisted_dynamic_after.fg,
    restore_persisted_dynamic_before.fg,
    'restoring a persisted highlight changed an unrelated dynamic frame',
    scope
  )

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
