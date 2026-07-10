local h = require('tests.helpers')
local scope = 'hlcraft dynamic runtime'

local config = require('hlcraft.config')
local timers = require('hlcraft.core.timers')
local runtime = require('hlcraft.dynamic.runtime')
local store = require('hlcraft.engine.store')

local runtime_dynamic = {
  fg = {
    version = 1,
    duration = 2000,
    loop = 'repeat',
    interpolation = 'linear',
    timeline = {
      { at = 0, color = '#000000' },
      { at = 1, color = '#ffffff' },
    },
  },
  bg = {
    version = 1,
    duration = 2000,
    loop = 'repeat',
    interpolation = 'linear',
    timeline = {
      { at = 0, color = 'base' },
    },
    transforms = {
      {
        type = 'brightness',
        interpolation = 'linear',
        timeline = {
          { at = 0, value = 0.75 },
          { at = 1, value = 0.75 },
        },
      },
    },
  },
}

config.setup({
  dynamic = {
    interval_ms = 80,
  },
})
vim.api.nvim_set_hl(0, 'HlcraftDynamicRuntime', { fg = '#111111', bg = '#808080' })
runtime.stop()
local bad_name_ok = pcall(runtime.sync_group, nil, { fg = '#111111' }, { dynamic = runtime_dynamic })
h.assert_true(not bad_name_ok, 'runtime accepted nil group name', scope)
local bad_base_spec_ok = pcall(runtime.sync_group, 'HlcraftDynamicRuntime', nil, { dynamic = runtime_dynamic })
h.assert_true(not bad_base_spec_ok, 'runtime accepted nil base spec', scope)
local bad_entry_ok = pcall(runtime.sync_group, 'HlcraftDynamicRuntime', { fg = '#111111' }, nil)
h.assert_true(not bad_entry_ok, 'runtime accepted nil entry', scope)
local bad_dynamic_ok = pcall(runtime.sync_group, 'HlcraftDynamicRuntime', { fg = '#111111' }, {
  dynamic = {
    fg = {
      version = 1,
      timeline = {},
    },
  },
})
h.assert_true(not bad_dynamic_ok, 'runtime accepted invalid dynamic override', scope)
local bad_clear_spec_ok = pcall(runtime.clear_group, 'HlcraftDynamicRuntime', 'bad-spec')
h.assert_true(not bad_clear_spec_ok, 'runtime accepted invalid restore spec', scope)
local bad_base_name_ok = pcall(runtime.base_spec, nil)
h.assert_true(not bad_base_name_ok, 'runtime base_spec accepted nil group name', scope)
local spaced_name_ok = pcall(runtime.base_spec, 'Bad Name')
h.assert_true(not spaced_name_ok, 'runtime base_spec accepted whitespace in group name', scope)
local command_name_ok = pcall(runtime.clear_group, 'Bad|Name')
h.assert_true(not command_name_ok, 'runtime clear_group accepted command separators in group name', scope)
local bad_tick_time_ok = pcall(runtime.tick, math.huge)
h.assert_true(not bad_tick_time_ok, 'runtime accepted infinite tick time', scope)
runtime.sync_group('HlcraftDynamicRuntime', { fg = '#111111', bg = '#808080' }, {
  dynamic = runtime_dynamic,
})
h.assert_equal(runtime.active_count(), 1, 'runtime did not register a dynamic task', scope)
runtime.tick(1000)
local enabled_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(enabled_spec.fg, tonumber('808080', 16), 'runtime did not use configured custom fg', scope)
local transform_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(transform_spec.bg, tonumber('606060', 16), 'runtime did not use configured custom bg transform', scope)

runtime.stop()
h.assert_equal(runtime.active_count(), 0, 'runtime stop did not clear dynamic tasks', scope)
local stopped_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(stopped_spec.fg, tonumber('111111', 16), 'runtime stop did not restore fg', scope)
h.assert_equal(stopped_spec.bg, tonumber('808080', 16), 'runtime stop did not restore bg', scope)

local original_set_hl = store.data.original_set_hl
runtime.sync_group('HlcraftDynamicRuntimeTickFailure', { fg = '#111111' }, {
  dynamic = {
    fg = runtime_dynamic.fg,
  },
})
store.data.original_set_hl = function()
  error('apply failed')
end
local tick_failure_ok = pcall(runtime.tick, 1000)
store.data.original_set_hl = original_set_hl
h.assert_true(not tick_failure_ok, 'runtime tick swallowed failed highlight apply', scope)
h.assert_true(
  runtime.base_spec('HlcraftDynamicRuntimeTickFailure') ~= nil,
  'failed runtime tick dropped dynamic task',
  scope
)
local tick_failure_clear_result = runtime.clear_group('HlcraftDynamicRuntimeTickFailure', { fg = '#111111' })
h.assert_true(tick_failure_clear_result, 'runtime tick failure cleanup did not restore highlight', scope)

runtime.sync_group('HlcraftDynamicRuntimeClearFailure', { fg = '#111111' }, {
  dynamic = {
    fg = runtime_dynamic.fg,
  },
})
store.data.original_set_hl = function()
  error('restore failed')
end
local clear_failure_result = runtime.clear_group('HlcraftDynamicRuntimeClearFailure', { fg = '#111111' })
store.data.original_set_hl = original_set_hl
h.assert_true(not clear_failure_result, 'runtime clear reported success after failed restore', scope)
h.assert_true(
  runtime.base_spec('HlcraftDynamicRuntimeClearFailure') ~= nil,
  'failed runtime clear dropped dynamic task',
  scope
)
local clear_retry_result = runtime.clear_group('HlcraftDynamicRuntimeClearFailure', { fg = '#111111' })
h.assert_true(clear_retry_result, 'runtime clear retry reported failure after restored highlight', scope)
h.assert_true(
  runtime.base_spec('HlcraftDynamicRuntimeClearFailure') == nil,
  'runtime clear retry kept restored dynamic task',
  scope
)

runtime.sync_group('HlcraftDynamicRuntimeSyncClearFailure', { fg = '#111111' }, {
  dynamic = {
    fg = runtime_dynamic.fg,
  },
})
store.data.original_set_hl = function()
  error('restore failed')
end
local sync_clear_failure_ok = pcall(runtime.sync_group, 'HlcraftDynamicRuntimeSyncClearFailure', { fg = '#111111' }, {})
store.data.original_set_hl = original_set_hl
h.assert_true(not sync_clear_failure_ok, 'runtime sync accepted failed dynamic clear', scope)
h.assert_true(
  runtime.base_spec('HlcraftDynamicRuntimeSyncClearFailure') ~= nil,
  'failed runtime sync clear dropped dynamic task',
  scope
)
local sync_clear_retry_result = runtime.clear_group('HlcraftDynamicRuntimeSyncClearFailure', { fg = '#111111' })
h.assert_true(sync_clear_retry_result, 'runtime sync clear retry reported failure after restored highlight', scope)

runtime.sync_group('HlcraftDynamicRuntimeStopFailure', { fg = '#111111' }, {
  dynamic = {
    fg = runtime_dynamic.fg,
  },
})
store.data.original_set_hl = function()
  error('restore failed')
end
local stop_failure_result = runtime.stop()
store.data.original_set_hl = original_set_hl
h.assert_true(not stop_failure_result, 'runtime stop reported success after failed restore', scope)
h.assert_true(
  runtime.base_spec('HlcraftDynamicRuntimeStopFailure') ~= nil,
  'failed runtime stop dropped dynamic task',
  scope
)
local stop_retry_result = runtime.stop()
h.assert_true(stop_retry_result, 'runtime stop retry reported failure after restored highlights', scope)
h.assert_true(
  runtime.base_spec('HlcraftDynamicRuntimeStopFailure') == nil,
  'runtime stop retry kept restored dynamic task',
  scope
)

runtime.reset()
local cleanup_timer_stop_calls = 0
local cleanup_timer_close_calls = 0
local cleanup_timer_should_fail = true
local cleanup_timer_original_repeating = timers.repeating
timers.repeating = function()
  return {
    stop = function()
      cleanup_timer_stop_calls = cleanup_timer_stop_calls + 1
    end,
    close = function()
      cleanup_timer_close_calls = cleanup_timer_close_calls + 1
      if cleanup_timer_should_fail then
        error('timer close failed')
      end
    end,
  }
end
local cleanup_timer_stop_ok
local cleanup_timer_running
local cleanup_timer_stub_ok, cleanup_timer_stub_err = xpcall(function()
  runtime.sync_group('HlcraftDynamicRuntimeTimerCleanupFailure', { fg = '#111111' }, {
    dynamic = {
      fg = runtime_dynamic.fg,
    },
  })
  cleanup_timer_stop_ok = pcall(runtime.stop)
  cleanup_timer_running = runtime.capture().running
  cleanup_timer_should_fail = false
  runtime.reset()
end, debug.traceback)
timers.repeating = cleanup_timer_original_repeating
if not cleanup_timer_stub_ok then
  error(cleanup_timer_stub_err, 0)
end
h.assert_true(not cleanup_timer_stop_ok, 'runtime stop swallowed a timer cleanup failure', scope)
h.assert_true(cleanup_timer_running, 'runtime stop dropped a timer after failed cleanup', scope)
h.assert_equal(cleanup_timer_stop_calls, 2, 'runtime timer cleanup retry did not stop the preserved timer', scope)
h.assert_equal(cleanup_timer_close_calls, 2, 'runtime timer cleanup retry did not close the preserved timer', scope)

runtime.reset()
local restore_failure_original_repeating = timers.repeating
timers.repeating = function()
  return nil
end
local restore_timer_failure_ok
local restore_timer_stub_ok, restore_timer_stub_err = xpcall(function()
  restore_timer_failure_ok = pcall(runtime.restore, {
    live_specs = {
      HlcraftDynamicRuntimeRestoreTimerFailure = {
        fg = '#111111',
      },
    },
    running = true,
    tasks = {
      HlcraftDynamicRuntimeRestoreTimerFailure = {
        base_spec = {
          fg = '#111111',
        },
        dynamic = {
          fg = runtime_dynamic.fg,
        },
      },
    },
  })
end, debug.traceback)
timers.repeating = restore_failure_original_repeating
if not restore_timer_stub_ok then
  error(restore_timer_stub_err, 0)
end
h.assert_true(not restore_timer_failure_ok, 'runtime restore accepted failed timer restart', scope)
h.assert_equal(runtime.active_count(), 0, 'failed runtime restore kept partially restored tasks', scope)

runtime.reset()
local previous_timer_stopped = 0
local previous_timer_closed = 0
local preserve_timer_original_repeating = timers.repeating
timers.repeating = function()
  return {
    stop = function()
      previous_timer_stopped = previous_timer_stopped + 1
    end,
    close = function()
      previous_timer_closed = previous_timer_closed + 1
    end,
  }
end
local restore_preserve_timer_ok
local preserved_timer_start_result
local preserve_timer_stub_ok, preserve_timer_stub_err = xpcall(function()
  runtime.sync_group('HlcraftDynamicRuntimeRestorePrevious', { fg = '#111111' }, {
    dynamic = {
      fg = runtime_dynamic.fg,
    },
  })
  timers.repeating = function()
    return nil
  end
  restore_preserve_timer_ok = pcall(runtime.restore, {
    live_specs = {
      HlcraftDynamicRuntimeRestoreReplacement = {
        fg = '#222222',
      },
    },
    running = true,
    tasks = {
      HlcraftDynamicRuntimeRestoreReplacement = {
        base_spec = {
          fg = '#222222',
        },
        dynamic = {
          fg = runtime_dynamic.fg,
        },
      },
    },
  })
  preserved_timer_start_result = runtime.start()
end, debug.traceback)
timers.repeating = preserve_timer_original_repeating
if not preserve_timer_stub_ok then
  error(preserve_timer_stub_err, 0)
end
h.assert_true(not restore_preserve_timer_ok, 'runtime restore accepted replacement timer start failure', scope)
h.assert_equal(
  runtime.base_spec('HlcraftDynamicRuntimeRestorePrevious').fg,
  '#111111',
  'failed runtime restore dropped previous task state',
  scope
)
h.assert_equal(previous_timer_stopped, 0, 'failed runtime restore stopped the previous timer', scope)
h.assert_equal(previous_timer_closed, 0, 'failed runtime restore closed the previous timer', scope)
h.assert_true(preserved_timer_start_result, 'failed runtime restore lost the previous timer handle', scope)
runtime.clear_group('HlcraftDynamicRuntimeRestorePrevious', { fg = '#111111' })

runtime.reset()
local replace_stop_failed = true
local replace_stop_calls = 0
local replace_close_calls = 0
local replace_stop_original_repeating = timers.repeating
timers.repeating = function()
  return {
    stop = function()
      replace_stop_calls = replace_stop_calls + 1
    end,
    close = function()
      replace_close_calls = replace_close_calls + 1
      if replace_stop_failed then
        error('previous timer close failed')
      end
    end,
  }
end
local replace_stop_restore_ok
local replace_stop_running
local replace_stop_previous_task
local replace_stop_stub_ok, replace_stop_stub_err = xpcall(function()
  runtime.sync_group('HlcraftDynamicRuntimeRestoreStopFailure', { fg = '#111111' }, {
    dynamic = {
      fg = runtime_dynamic.fg,
    },
  })
  replace_stop_restore_ok = pcall(runtime.restore, {
    live_specs = {},
    running = false,
    tasks = {},
  })
  replace_stop_running = runtime.capture().running
  replace_stop_previous_task = runtime.base_spec('HlcraftDynamicRuntimeRestoreStopFailure')
  replace_stop_failed = false
  runtime.reset()
end, debug.traceback)
timers.repeating = replace_stop_original_repeating
if not replace_stop_stub_ok then
  error(replace_stop_stub_err, 0)
end
h.assert_true(not replace_stop_restore_ok, 'runtime restore swallowed previous timer cleanup failure', scope)
h.assert_true(replace_stop_running, 'runtime restore dropped the previous timer after failed cleanup', scope)
h.assert_true(
  replace_stop_previous_task and replace_stop_previous_task.fg == '#111111',
  'runtime restore replaced previous tasks before timer cleanup completed',
  scope
)
h.assert_equal(replace_stop_calls, 2, 'runtime restore retry did not stop the preserved previous timer', scope)
h.assert_equal(replace_close_calls, 2, 'runtime restore retry did not close the preserved previous timer', scope)

local scheduled_tick
local original_repeating = timers.repeating
local original_schedule = vim.schedule
local timer_cleanup_failed = true
timers.repeating = function(_, callback)
  scheduled_tick = callback
  return {
    stop = function() end,
    close = function()
      if timer_cleanup_failed then
        error('timer close failed')
      end
    end,
  }
end
vim.schedule = function(callback)
  callback()
end
local notifications = {}
local timer_ok
local timer_running_after_failure
local timer_stub_ok, timer_stub_err = xpcall(function()
  runtime.restore({
    live_specs = {
      HlcraftDynamicRuntimeTimerFailure = {
        fg = '#111111',
      },
    },
    running = true,
    tasks = {
      HlcraftDynamicRuntimeTimerFailure = {
        base_spec = {
          fg = '#111111',
        },
        dynamic = false,
      },
    },
  })
  timer_ok = h.with_notify_stub(function()
    return pcall(scheduled_tick)
  end, function(message)
    notifications[#notifications + 1] = message
  end)
  timer_running_after_failure = runtime.capture().running
end, debug.traceback)
timers.repeating = original_repeating
vim.schedule = original_schedule
if not timer_stub_ok then
  error(timer_stub_err, 0)
end
timer_cleanup_failed = false
runtime.reset()
h.assert_true(timer_ok, 'runtime timer error escaped scheduled callback', scope)
h.assert_true(timer_running_after_failure, 'runtime timer failure dropped a timer after failed cleanup', scope)
h.assert_true(
  notifications[1]
    and notifications[1]:find('dynamic runtime timer', 1, true) ~= nil
    and notifications[1]:find('timer cleanup failed', 1, true) ~= nil,
  'runtime timer error did not report the cleanup failure',
  scope
)

runtime.reset()
local stale_callbacks = {}
local stale_scheduled = {}
local stale_repeating_calls = 0
timers.repeating = function(_, callback)
  stale_repeating_calls = stale_repeating_calls + 1
  stale_callbacks[#stale_callbacks + 1] = callback
  return {
    stop = function() end,
    close = function() end,
  }
end
vim.schedule = function(callback)
  stale_scheduled[#stale_scheduled + 1] = callback
end
local stale_timer_stub_ok, stale_timer_stub_err = xpcall(function()
  runtime.sync_group('HlcraftDynamicRuntimeStaleTimer', { fg = '#111111' }, {
    dynamic = {
      fg = runtime_dynamic.fg,
    },
  })
  stale_callbacks[1]()
  runtime.reset()
  runtime.sync_group('HlcraftDynamicRuntimeFreshTimer', { fg = '#222222' }, {
    dynamic = {
      fg = runtime_dynamic.fg,
    },
  })
  store.data.original_set_hl = function()
    error('stale timer apply failed')
  end
  h.with_notify_stub(function()
    stale_scheduled[1]()
  end)
  store.data.original_set_hl = original_set_hl
  runtime.start()
end, debug.traceback)
timers.repeating = original_repeating
vim.schedule = original_schedule
store.data.original_set_hl = original_set_hl
runtime.reset()
if not stale_timer_stub_ok then
  error(stale_timer_stub_err, 0)
end
h.assert_equal(stale_repeating_calls, 2, 'stale timer callback closed the replacement timer', scope)

vim.api.nvim_set_hl(0, 'HlcraftDynamicRuntimeCapturedFrame', { fg = '#111111' })
runtime.sync_group('HlcraftDynamicRuntimeCapturedFrame', { fg = '#111111' }, {
  dynamic = {
    fg = runtime_dynamic.fg,
  },
})
runtime.tick(1000)
local captured_frame_before = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntimeCapturedFrame', create = false })
local captured_frame = runtime.capture()
vim.api.nvim_set_hl(0, 'HlcraftDynamicRuntimeCapturedFrame', { fg = '#222222' })
runtime.restore(captured_frame)
local captured_frame_after = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntimeCapturedFrame', create = false })
runtime.clear_group('HlcraftDynamicRuntimeCapturedFrame', { fg = '#111111' })
h.assert_equal(captured_frame_after.fg, captured_frame_before.fg, 'runtime restore lost the captured live frame', scope)

runtime.reset()
local stopped_timer_callback
local stopped_timer_repeating_calls = 0
timers.repeating = function(_, callback)
  stopped_timer_repeating_calls = stopped_timer_repeating_calls + 1
  stopped_timer_callback = callback
  return {
    stop = function() end,
    close = function() end,
  }
end
vim.schedule = function(callback)
  callback()
end
local stopped_timer_calls_after_restore
local stopped_timer_stub_ok, stopped_timer_stub_err = xpcall(function()
  runtime.sync_group('HlcraftDynamicRuntimeStoppedCapture', { fg = '#111111' }, {
    dynamic = {
      fg = runtime_dynamic.fg,
    },
  })
  store.data.original_set_hl = function()
    error('captured timer apply failed')
  end
  h.with_notify_stub(function()
    stopped_timer_callback()
  end)
  store.data.original_set_hl = original_set_hl
  local stopped_capture = runtime.capture()
  runtime.restore(stopped_capture)
  stopped_timer_calls_after_restore = stopped_timer_repeating_calls
  runtime.start()
end, debug.traceback)
timers.repeating = original_repeating
vim.schedule = original_schedule
store.data.original_set_hl = original_set_hl
runtime.reset()
if not stopped_timer_stub_ok then
  error(stopped_timer_stub_err, 0)
end
h.assert_equal(stopped_timer_calls_after_restore, 1, 'runtime restore restarted a captured stopped timer', scope)
h.assert_equal(stopped_timer_repeating_calls, 2, 'runtime start did not restart the captured stopped timer', scope)

config.setup({})

print('hlcraft dynamic runtime: OK')
