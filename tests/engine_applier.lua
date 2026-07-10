local h = require('tests.helpers')
local scope = 'hlcraft engine applier'
local assert_fails = h.scoped_assert_fails(scope)

local applier = require('hlcraft.engine.applier')
local config = require('hlcraft.config')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local store = require('hlcraft.engine.store')
local timers = require('hlcraft.core.timers')

local original_get_hl = vim.api.nvim_get_hl
local original_set_hl = vim.api.nvim_set_hl
local original_store_set_hl = store.data.original_set_hl
local original_config = config.config
local original_applying = store.data.applying
local original_hooked = store.data.hooked
local original_group = store.data.group
local original_pending = vim.deepcopy(store.data.pending)
local original_base_specs = vim.deepcopy(store.data.base_specs)
local original_active = vim.deepcopy(store.data.active)
local original_schedule = vim.schedule
local original_timers_repeating = timers.repeating

local function restore_state()
  vim.api.nvim_get_hl = original_get_hl
  if vim.api.nvim_set_hl ~= original_set_hl then
    vim.api.nvim_set_hl = original_set_hl
  end
  vim.schedule = original_schedule
  timers.repeating = original_timers_repeating
  store.data.original_set_hl = original_store_set_hl
  dynamic_runtime.stop()
  config.config = original_config
  store.data.applying = original_applying
  store.data.hooked = original_hooked
  store.data.group = original_group
  store.data.pending = original_pending
  store.data.base_specs = original_base_specs
  store.data.active = original_active
end

local ok, err = xpcall(function()
  local name = 'HlcraftEngineApplierPending'
  local missing_apply_name_ok = pcall(applier.apply_group, nil)
  h.assert_true(not missing_apply_name_ok, 'applier accepted missing highlight name', scope)
  local empty_apply_name_ok = pcall(applier.apply_group, '')
  h.assert_true(not empty_apply_name_ok, 'applier accepted empty highlight name', scope)

  local invalid_base_name = 'HlcraftEngineApplierInvalidBase'
  vim.api.nvim_set_hl(0, invalid_base_name, { fg = '#111111' })
  store.data.applying = false
  store.data.original_set_hl = original_set_hl
  store.data.base_specs = {
    [invalid_base_name] = false,
  }
  store.data.active = {
    [invalid_base_name] = {
      fg = '#222222',
    },
  }
  local invalid_base_ok = pcall(applier.apply_group, invalid_base_name)
  h.assert_true(not invalid_base_ok, 'applier accepted invalid cached base spec', scope)
  h.assert_true(not store.data.applying, 'applier kept applying state after failed apply', scope)

  local guarded_apply_name = 'HlcraftEngineApplierGuardedApply'
  vim.api.nvim_set_hl(0, guarded_apply_name, { fg = '#111111' })
  store.data.applying = true
  store.data.base_specs = {}
  store.data.active = {
    [guarded_apply_name] = {
      fg = '#222222',
    },
  }
  local guarded_apply_ok = pcall(applier.apply_group, guarded_apply_name)
  h.assert_true(guarded_apply_ok, 'applier failed while an applying guard was already active', scope)
  h.assert_true(store.data.applying, 'applier cleared an existing applying guard', scope)
  store.data.applying = false

  local dynamic_name = 'HlcraftEngineApplierDynamicReapply'
  vim.api.nvim_set_hl(0, dynamic_name, { fg = '#111111' })
  store.data.original_set_hl = original_set_hl
  store.data.base_specs = {}
  store.data.active = {
    [dynamic_name] = {
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
  applier.apply_group(dynamic_name)
  h.assert_equal(
    dynamic_runtime.base_spec(dynamic_name).fg,
    '#111111',
    'dynamic runtime did not capture the initial base',
    scope
  )
  dynamic_runtime.tick(500)
  applier.refresh_base_specs()
  applier.apply_group(dynamic_name)
  h.assert_equal(
    dynamic_runtime.base_spec(dynamic_name).fg,
    '#111111',
    'dynamic runtime default refresh captured an animated color',
    scope
  )
  vim.api.nvim_set_hl(0, dynamic_name, { fg = '#222222' })
  applier.refresh_base_specs({ restore_dynamic = false })
  applier.apply_group(dynamic_name)
  h.assert_equal(
    dynamic_runtime.base_spec(dynamic_name).fg,
    '#222222',
    'dynamic runtime reapply captured a stale base spec',
    scope
  )
  local dynamic_failure_base = dynamic_runtime.base_spec(dynamic_name)
  store.data.base_specs = {
    [dynamic_name] = false,
  }
  local dynamic_failure_ok = pcall(applier.apply_group, dynamic_name)
  h.assert_true(not dynamic_failure_ok, 'applier accepted failed dynamic reapply', scope)
  h.assert_true(
    vim.deep_equal(dynamic_runtime.base_spec(dynamic_name), dynamic_failure_base),
    'failed dynamic reapply dropped runtime task',
    scope
  )
  store.data.base_specs = {}
  local dynamic_set_failure_base = dynamic_runtime.base_spec(dynamic_name)
  store.data.original_set_hl = function()
    error('set failed')
  end
  local dynamic_set_failure_ok = h.with_notify_stub(function()
    return pcall(applier.apply_group, dynamic_name)
  end)
  h.assert_true(dynamic_set_failure_ok, 'applier threw on failed nvim_set_hl', scope)
  h.assert_true(
    vim.deep_equal(dynamic_runtime.base_spec(dynamic_name), dynamic_set_failure_base),
    'warned dynamic reapply dropped runtime task',
    scope
  )
  store.data.original_set_hl = original_set_hl

  local capture_failure_name = 'HlcraftEngineApplierCaptureFailure'
  vim.api.nvim_set_hl(0, capture_failure_name, { fg = '#111111' })
  dynamic_runtime.sync_group(capture_failure_name, { fg = '#111111' }, {
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
  local capture_failure_before = vim.api.nvim_get_hl(0, { name = capture_failure_name, create = false })
  store.data.base_specs = {}
  store.data.active = {
    [capture_failure_name] = {
      fg = '#222222',
    },
  }
  local capture_calls = 0
  vim.api.nvim_get_hl = function(...)
    capture_calls = capture_calls + 1
    if capture_calls == 1 then
      error('live highlight capture failed')
    end
    return original_get_hl(...)
  end
  store.data.original_set_hl = function(ns, applied_name, spec)
    if applied_name == capture_failure_name and spec and spec.fg == '#222222' then
      error('apply failed')
    end
    return original_set_hl(ns, applied_name, spec)
  end
  local capture_failure_ok = h.with_notify_stub(function()
    return pcall(applier.apply_group, capture_failure_name)
  end)
  vim.api.nvim_get_hl = original_get_hl
  store.data.original_set_hl = original_set_hl
  local capture_failure_task = dynamic_runtime.base_spec(capture_failure_name)
  local capture_failure_after = vim.api.nvim_get_hl(0, { name = capture_failure_name, create = false })
  dynamic_runtime.clear_group(capture_failure_name, { fg = '#111111' })
  h.assert_true(not capture_failure_ok, 'applier accepted failed live highlight capture', scope)
  h.assert_true(capture_failure_task ~= nil, 'failed live highlight capture dropped the dynamic task', scope)
  h.assert_equal(
    capture_failure_after.fg,
    capture_failure_before.fg,
    'failed live highlight capture changed the live dynamic frame',
    scope
  )

  local dynamic_refresh_failure_name = 'HlcraftEngineApplierDynamicRefreshFailure'
  vim.api.nvim_set_hl(0, dynamic_refresh_failure_name, { fg = '#888888' })
  dynamic_runtime.sync_group(dynamic_refresh_failure_name, { fg = '#111111' }, {
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
  store.data.base_specs = {}
  local dynamic_refresh_existing_base = dynamic_runtime.base_spec(dynamic_name)
  store.data.original_set_hl = function(_, name, spec)
    if name == dynamic_refresh_failure_name then
      error('restore failed')
    end
    return original_set_hl(0, name, spec)
  end
  local dynamic_refresh_failure_ok = pcall(applier.refresh_base_specs)
  store.data.original_set_hl = original_set_hl
  h.assert_true(not dynamic_refresh_failure_ok, 'applier refreshed base specs after failed dynamic stop', scope)
  h.assert_true(
    store.data.base_specs[dynamic_refresh_failure_name] == nil,
    'failed dynamic refresh captured animated base',
    scope
  )
  h.assert_equal(
    dynamic_runtime.base_spec(dynamic_refresh_failure_name).fg,
    '#111111',
    'failed dynamic refresh dropped runtime task',
    scope
  )
  h.assert_true(
    vim.deep_equal(dynamic_runtime.base_spec(dynamic_name), dynamic_refresh_existing_base),
    'failed dynamic refresh dropped another runtime task',
    scope
  )
  dynamic_runtime.clear_group(dynamic_refresh_failure_name, { fg = '#111111' })

  local dynamic_clear_failure_name = 'HlcraftEngineApplierDynamicClearFailure'
  vim.api.nvim_set_hl(0, dynamic_clear_failure_name, { fg = '#888888' })
  dynamic_runtime.sync_group(dynamic_clear_failure_name, { fg = '#111111' }, {
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
  store.data.base_specs = {}
  store.data.active = {
    [dynamic_clear_failure_name] = {
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
  local clear_failure_calls = 0
  store.data.original_set_hl = function(...)
    clear_failure_calls = clear_failure_calls + 1
    if clear_failure_calls == 1 then
      error('restore failed')
    end
    return original_set_hl(...)
  end
  local dynamic_clear_failure_ok = h.with_notify_stub(function()
    return pcall(applier.apply_group, dynamic_clear_failure_name)
  end)
  h.assert_true(dynamic_clear_failure_ok, 'applier threw on failed dynamic clear restore', scope)
  h.assert_equal(
    dynamic_runtime.base_spec(dynamic_clear_failure_name).fg,
    '#111111',
    'failed dynamic clear reapply recaptured animated base',
    scope
  )
  store.data.original_set_hl = original_set_hl

  local dynamic_clear_empty_name = 'HlcraftEngineApplierDynamicClearEmpty'
  vim.api.nvim_set_hl(0, dynamic_clear_empty_name, { fg = '#111111' })
  dynamic_runtime.sync_group(dynamic_clear_empty_name, { fg = '#111111' }, {
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
  store.data.active = {}
  store.data.base_specs = {
    [dynamic_clear_empty_name] = {
      fg = '#111111',
    },
  }
  store.data.original_set_hl = function()
    error('restore failed')
  end
  local dynamic_clear_empty_ok = h.with_notify_stub(function()
    return pcall(applier.apply_group, dynamic_clear_empty_name)
  end)
  store.data.original_set_hl = original_set_hl
  h.assert_true(dynamic_clear_empty_ok, 'applier threw on failed dynamic clear without override', scope)
  h.assert_equal(
    dynamic_runtime.base_spec(dynamic_clear_empty_name).fg,
    '#111111',
    'failed dynamic clear without override dropped runtime task',
    scope
  )
  dynamic_runtime.clear_group(dynamic_clear_empty_name, { fg = '#111111' })

  store.data.original_set_hl = function() end
  store.data.hooked = false
  store.data.pending = {
    [name] = true,
  }
  store.data.base_specs = {}
  store.data.active = {}

  applier.install_pending_hook()
  local invalid_spec_ok = pcall(vim.api.nvim_set_hl, 0, name, nil)
  h.assert_true(not invalid_spec_ok, 'pending hook accepted nil highlight spec', scope)
  h.assert_true(store.data.base_specs[name] == nil, 'pending hook captured nil spec as a base spec', scope)

  local pending_failure_name = 'HlcraftEngineApplierPendingFailure'
  store.data.original_set_hl = function(ns, applied_name, spec)
    if applied_name == pending_failure_name and spec and spec.fg == '#222222' then
      error('pending apply failed')
    end
    return original_set_hl(ns, applied_name, spec)
  end
  store.data.hooked = false
  store.data.pending = {
    [pending_failure_name] = true,
  }
  store.data.active = {
    [pending_failure_name] = {
      fg = '#222222',
    },
  }
  applier.install_pending_hook()
  local pending_failure_ok = h.with_notify_stub(function()
    return pcall(vim.api.nvim_set_hl, 0, pending_failure_name, { fg = '#101010' })
  end)
  h.assert_true(pending_failure_ok, 'pending hook apply failure escaped set_hl', scope)
  h.assert_true(store.data.pending[pending_failure_name], 'failed pending hook apply dropped pending state', scope)
  h.assert_true(store.data.hooked, 'failed pending hook apply uninstalled pending hook', scope)

  local pending_dynamic_failure_name = 'HlcraftEngineApplierPendingDynamicFailure'
  dynamic_runtime.reset()
  store.data.original_set_hl = original_set_hl
  store.data.hooked = false
  store.data.pending = {
    [pending_dynamic_failure_name] = true,
  }
  store.data.base_specs = {}
  store.data.active = {
    [pending_dynamic_failure_name] = {
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
  applier.install_pending_hook()
  local original_repeating = timers.repeating
  timers.repeating = function()
    return nil
  end
  local pending_dynamic_notifications = {}
  local pending_dynamic_failure_ok = h.with_notify_stub(function()
    return pcall(vim.api.nvim_set_hl, 0, pending_dynamic_failure_name, { fg = '#101010' })
  end, function(message)
    pending_dynamic_notifications[#pending_dynamic_notifications + 1] = message
  end)
  timers.repeating = original_repeating
  h.assert_true(pending_dynamic_failure_ok, 'pending hook dynamic failure escaped set_hl', scope)
  h.assert_true(
    store.data.pending[pending_dynamic_failure_name],
    'failed pending hook dynamic apply dropped pending state',
    scope
  )
  h.assert_true(store.data.hooked, 'failed pending hook dynamic apply uninstalled pending hook', scope)
  h.assert_true(
    pending_dynamic_notifications[1]
      and pending_dynamic_notifications[1]:find('dynamic runtime failed to start timer', 1, true) ~= nil,
    'failed pending hook dynamic apply was not notified',
    scope
  )

  applier.uninstall_pending_hook()
  local valid_spec = {
    fg = '#101010',
  }
  store.data.original_set_hl = function() end
  store.data.hooked = false
  store.data.pending = {
    [name] = true,
  }
  store.data.active = {}
  applier.install_pending_hook()
  vim.api.nvim_set_hl(0, name, valid_spec)
  h.assert_equal(store.data.base_specs[name].fg, '#101010', 'pending hook did not capture valid base spec', scope)
  h.assert_true(store.data.base_specs[name] ~= valid_spec, 'pending hook kept mutable base spec reference', scope)
  h.assert_true(vim.api.nvim_set_hl == store.data.original_set_hl, 'pending hook did not uninstall itself', scope)

  config.config = vim.tbl_deep_extend('force', vim.deepcopy(config.config), {
    persistence = {
      reapply_events = {
        enabled = true,
        events = {
          'ColorScheme',
        },
      },
    },
  })
  assert_fails(function()
    applier.register_reapply_events(nil)
  end, 'applier accepted missing replay callback')

  local stale_reapply_group = vim.api.nvim_create_augroup('HlcraftEngineApplierStaleReapply', { clear = true })
  store.data.group = stale_reapply_group
  local scheduled_reapply = nil
  vim.schedule = function(callback)
    scheduled_reapply = callback
  end
  local stale_replay_count = 0
  applier.register_reapply_events(function()
    stale_replay_count = stale_replay_count + 1
  end)
  vim.api.nvim_exec_autocmds('ColorScheme', {
    group = stale_reapply_group,
    modeline = false,
  })
  store.data.group = vim.api.nvim_create_augroup('HlcraftEngineApplierFreshReapply', { clear = true })
  scheduled_reapply()
  vim.schedule = original_schedule
  h.assert_equal(stale_replay_count, 0, 'stale scheduled reapply hook ran after augroup changed', scope)

  local reused_reapply_group = vim.api.nvim_create_augroup('HlcraftEngineApplierReusedReapply', { clear = true })
  store.data.group = reused_reapply_group
  local reused_scheduled = {}
  vim.schedule = function(callback)
    reused_scheduled[#reused_scheduled + 1] = callback
  end
  local reused_stale_replay_count = 0
  applier.register_reapply_events(function()
    reused_stale_replay_count = reused_stale_replay_count + 1
  end)
  vim.api.nvim_exec_autocmds('ColorScheme', {
    group = reused_reapply_group,
    modeline = false,
  })
  store.data.group = vim.api.nvim_create_augroup('HlcraftEngineApplierReusedReapply', { clear = true })
  h.assert_equal(store.data.group, reused_reapply_group, 'reused augroup test did not preserve the group id', scope)
  applier.register_reapply_events(function() end)
  reused_scheduled[1]()
  vim.schedule = original_schedule
  h.assert_equal(reused_stale_replay_count, 0, 'stale reapply hook ran after augroup id reuse', scope)

  local reapply_group = vim.api.nvim_create_augroup('HlcraftEngineApplierReapplyFailure', { clear = true })
  store.data.group = reapply_group
  vim.schedule = function(callback)
    callback()
  end
  local notifications = {}
  local event_ok = h.with_notify_stub(function()
    applier.register_reapply_events(function()
      error('replay exploded')
    end)
    return pcall(vim.api.nvim_exec_autocmds, 'ColorScheme', {
      group = reapply_group,
      modeline = false,
    })
  end, function(message)
    notifications[#notifications + 1] = message
  end)
  vim.schedule = original_schedule
  h.assert_true(event_ok, 'applier reapply event error escaped the scheduled callback', scope)
  h.assert_true(
    notifications[1] and notifications[1]:find('replay exploded', 1, true) ~= nil,
    'applier reapply event error was not notified',
    scope
  )
end, debug.traceback)

restore_state()

if not ok then
  error(err, 0)
end

print('hlcraft engine applier: OK')
