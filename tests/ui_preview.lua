local h = require('tests.helpers')
local scope = 'hlcraft ui preview'

local config = require('hlcraft.config')
local preview = require('hlcraft.ui.preview')
local timers = require('hlcraft.core.timers')
local ui_state = require('hlcraft.ui.state')

local lhs = '<Plug>(HlcraftPreviewTest)'
pcall(vim.keymap.del, 'n', lhs)

local assert_fails = h.scoped_assert_fails(scope)

local ok, err = xpcall(function()
  assert_fails(function()
    preview.install_keymap(nil)
  end, 'preview keymap install accepted missing instance')
  assert_fails(function()
    preview.cleanup({
      state = {
        preview = false,
      },
    })
  end, 'preview cleanup accepted invalid preview state')
  assert_fails(function()
    preview.flash_current({
      state = {
        preview = ui_state.preview(),
      },
    })
  end, 'preview flash accepted missing results')
  assert_fails(function()
    preview.flash_current({
      state = {
        preview = ui_state.preview(),
        results = {
          [2] = { name = 'Late' },
        },
        list_cursor = 2,
      },
    })
  end, 'preview flash accepted sparse results')
  assert_fails(function()
    preview.flash_current({
      state = {
        preview = ui_state.preview(),
        results = {
          { name = 'Normal' },
        },
        detail_index = 0,
      },
    })
  end, 'preview flash accepted invalid detail index')
  assert_fails(function()
    preview.flash_current({
      state = {
        preview = ui_state.preview(),
        results = {
          { name = 'Normal' },
        },
        list_cursor = 0,
      },
    })
  end, 'preview flash accepted invalid list cursor')
  assert_fails(function()
    preview.uninstall_keymap({
      state = {
        preview = {
          keymap = false,
        },
      },
    })
  end, 'preview keymap uninstall accepted invalid keymap state')
  assert_fails(function()
    preview.uninstall_keymap({
      state = {
        preview = {
          keymap = {},
        },
      },
    })
  end, 'preview keymap uninstall accepted missing lhs')

  vim.keymap.set('n', lhs, '<Nop>', {
    silent = true,
    desc = 'original preview test mapping',
  })

  config.setup({
    keymaps = {
      preview = {
        lhs = lhs,
        mode = 'n',
        opts = {
          desc = 'custom hlcraft preview',
          silent = true,
          nowait = true,
        },
      },
    },
  })

  local instance = {
    state = {
      preview = ui_state.preview(),
      results = {},
    },
  }

  preview.install_keymap(instance)
  local installed = vim.fn.maparg(lhs, 'n', false, true)
  h.assert_equal(installed.desc, 'custom hlcraft preview', 'preview mapping did not use configured opts', scope)
  h.assert_true(type(installed.callback) == 'function', 'preview mapping did not expose a callback', scope)

  instance.state.results = {
    [2] = { name = 'BrokenPreview' },
  }
  instance.state.list_cursor = 2
  local keymap_notifications = {}
  local preview_callback_ok = h.with_notify_stub(function()
    return pcall(installed.callback)
  end, function(message)
    keymap_notifications[#keymap_notifications + 1] = message
  end)
  h.assert_true(preview_callback_ok, 'preview keymap callback error escaped', scope)
  h.assert_true(
    keymap_notifications[1] and keymap_notifications[1]:find('preview keymap failed', 1, true) ~= nil,
    'preview keymap callback error was not notified',
    scope
  )

  preview.uninstall_keymap(instance)
  local restored = vim.fn.maparg(lhs, 'n', false, true)
  h.assert_equal(restored.desc, 'original preview test mapping', 'preview mapping description was not restored', scope)
  h.assert_equal(restored.rhs, '<Nop>', 'preview mapping rhs was not restored', scope)
  h.assert_true(instance.state.preview.keymap == nil, 'preview keymap state was not cleared', scope)

  preview.install_keymap(instance)
  local delete_failure_keymap = instance.state.preview.keymap
  local original_keymap_del = vim.keymap.del
  vim.keymap.del = function()
    error('preview keymap delete failed')
  end
  local delete_failure_ok = pcall(preview.uninstall_keymap, instance)
  vim.keymap.del = original_keymap_del
  h.assert_true(not delete_failure_ok, 'preview keymap uninstall accepted failed delete', scope)
  h.assert_equal(
    instance.state.preview.keymap,
    delete_failure_keymap,
    'failed preview keymap delete dropped keymap state',
    scope
  )
  local leaked_preview_map = vim.fn.maparg(lhs, 'n', false, true)
  h.assert_equal(
    leaked_preview_map.desc,
    'custom hlcraft preview',
    'failed preview keymap delete lost active map',
    scope
  )
  preview.uninstall_keymap(instance)
  restored = vim.fn.maparg(lhs, 'n', false, true)
  h.assert_equal(restored.desc, 'original preview test mapping', 'preview keymap retry did not restore mapping', scope)

  local original_keymap_set = vim.keymap.set
  local failing_instance = {
    state = {
      preview = ui_state.preview(),
    },
  }
  vim.keymap.set = function()
    error('preview keymap failed')
  end
  local failing_install_ok = pcall(preview.install_keymap, failing_instance)
  vim.keymap.set = original_keymap_set
  h.assert_true(not failing_install_ok, 'preview accepted failed keymap install', scope)
  h.assert_true(failing_instance.state.preview.keymap == nil, 'failed preview keymap install kept state', scope)
  local preserved = vim.fn.maparg(lhs, 'n', false, true)
  h.assert_equal(
    preserved.desc,
    'original preview test mapping',
    'failed preview keymap install changed mapping',
    scope
  )
  h.assert_equal(preserved.rhs, '<Nop>', 'failed preview keymap install changed mapping rhs', scope)

  local rollback_lhs = '<Plug>(HlcraftPreviewRollbackFailure)'
  config.setup({
    keymaps = {
      preview = {
        lhs = rollback_lhs,
        mode = 'n',
      },
    },
  })
  local rollback_failure_instance = {
    state = {
      preview = ui_state.preview(),
    },
  }
  local original_maparg = vim.fn.maparg
  original_keymap_set = vim.keymap.set
  vim.fn.maparg = function(target_lhs, mode, ...)
    if target_lhs == rollback_lhs and mode == 'n' then
      return {
        lhs = rollback_lhs,
        rhs = false,
      }
    end
    return original_maparg(target_lhs, mode, ...)
  end
  vim.keymap.set = function()
    error('preview keymap failed')
  end
  local rollback_failure_ok, rollback_failure_err = pcall(preview.install_keymap, rollback_failure_instance)
  vim.fn.maparg = original_maparg
  vim.keymap.set = original_keymap_set
  h.assert_true(not rollback_failure_ok, 'preview accepted failed keymap install with failed rollback', scope)
  h.assert_true(
    tostring(rollback_failure_err):find('preview keymap failed', 1, true) ~= nil,
    'preview keymap rollback failure dropped original install error',
    scope
  )
  h.assert_true(
    tostring(rollback_failure_err):find('preview keymap restore requires a string rhs', 1, true) ~= nil,
    'preview keymap rollback failure did not report the restore error',
    scope
  )
  h.assert_true(
    rollback_failure_instance.state.preview.keymap == nil,
    'failed preview keymap rollback kept installed keymap state',
    scope
  )

  local preview_name = 'HlcraftUiPreviewFlash'
  vim.api.nvim_set_hl(0, preview_name, { fg = '#111111' })
  local flash_instance = {
    state = {
      preview = ui_state.preview(),
      results = {
        { name = preview_name },
      },
      list_cursor = 1,
    },
  }
  preview.flash_current(flash_instance)
  local flashed = vim.api.nvim_get_hl(0, { name = preview_name })
  h.assert_equal(flashed.fg, 0x00e5ff, 'preview flash did not apply highlight color', scope)
  preview.cleanup(flash_instance)
  local restored_hl = vim.api.nvim_get_hl(0, { name = preview_name })
  h.assert_equal(restored_hl.fg, 0x111111, 'preview cleanup did not restore highlight color', scope)

  vim.api.nvim_set_hl(0, preview_name, { fg = '#111111' })
  preview.flash_current(flash_instance)
  preview.flash_current(flash_instance)
  preview.cleanup(flash_instance)
  local repeated_restored_hl = vim.api.nvim_get_hl(0, { name = preview_name })
  h.assert_equal(repeated_restored_hl.fg, 0x111111, 'repeated preview flash restored preview color', scope)

  local first_timer_callback
  local second_timer_callback
  local preview_next_timer = 0
  local original_once_for_stale = timers.once
  local original_schedule_wrap_for_stale = vim.schedule_wrap
  local first_preview_name = 'HlcraftUiPreviewStaleFirst'
  local second_preview_name = 'HlcraftUiPreviewStaleSecond'
  vim.api.nvim_set_hl(0, first_preview_name, { fg = '#111111' })
  vim.api.nvim_set_hl(0, second_preview_name, { fg = '#222222' })
  vim.schedule_wrap = function(callback)
    return callback
  end
  timers.once = function(_, callback)
    preview_next_timer = preview_next_timer + 1
    if preview_next_timer == 1 then
      first_timer_callback = callback
    elseif preview_next_timer == 2 then
      second_timer_callback = callback
    end
    return {
      stop = function() end,
      close = function() end,
    }
  end
  local stale_timer_instance = {
    state = {
      preview = ui_state.preview(),
      results = {
        { name = first_preview_name },
        { name = second_preview_name },
      },
      list_cursor = 1,
    },
  }
  preview.flash_current(stale_timer_instance)
  stale_timer_instance.state.list_cursor = 2
  preview.flash_current(stale_timer_instance)
  h.assert_true(type(first_timer_callback) == 'function', 'first preview timer callback was not captured', scope)
  h.assert_true(type(second_timer_callback) == 'function', 'second preview timer callback was not captured', scope)
  first_timer_callback()
  timers.once = original_once_for_stale
  vim.schedule_wrap = original_schedule_wrap_for_stale
  local stale_second_hl = vim.api.nvim_get_hl(0, { name = second_preview_name })
  h.assert_equal(stale_second_hl.fg, 0x00e5ff, 'stale preview timer restored active preview', scope)
  h.assert_equal(
    stale_timer_instance.state.preview.name,
    second_preview_name,
    'stale preview timer cleared active preview name',
    scope
  )
  preview.cleanup(stale_timer_instance)

  local failed_timer_callback
  local failed_timer_handle = {
    stop = function()
      error('preview timer stop failed')
    end,
    close = function() end,
  }
  local failed_timer_name = 'HlcraftUiPreviewTimerCleanupFailure'
  vim.api.nvim_set_hl(0, failed_timer_name, { fg = '#333333' })
  vim.schedule_wrap = function(callback)
    return callback
  end
  timers.once = function(_, callback)
    failed_timer_callback = callback
    return failed_timer_handle
  end
  local failed_timer_instance = {
    state = {
      preview = ui_state.preview(),
      results = {
        { name = failed_timer_name },
      },
      list_cursor = 1,
    },
  }
  preview.flash_current(failed_timer_instance)
  local failed_timer_notifications = {}
  local failed_timer_callback_ok = h.with_notify_stub(function()
    return pcall(failed_timer_callback)
  end, function(message)
    failed_timer_notifications[#failed_timer_notifications + 1] = message
  end)
  timers.once = original_once_for_stale
  vim.schedule_wrap = original_schedule_wrap_for_stale
  local failed_timer_restored_hl = vim.api.nvim_get_hl(0, { name = failed_timer_name })
  h.assert_true(failed_timer_callback_ok, 'preview timer cleanup error escaped scheduled callback', scope)
  h.assert_equal(failed_timer_restored_hl.fg, 0x333333, 'preview timer cleanup failure blocked restore', scope)
  h.assert_equal(
    failed_timer_instance.state.preview.timer,
    failed_timer_handle,
    'preview timer cleanup failure dropped the live timer handle',
    scope
  )
  h.assert_true(
    failed_timer_notifications[1]
      and failed_timer_notifications[1]:find('preview timer', 1, true) ~= nil
      and failed_timer_notifications[1]:find('preview timer stop failed', 1, true) ~= nil,
    'preview timer cleanup failure was not notified',
    scope
  )
  failed_timer_instance.state.preview.timer = nil

  local edited_timer_callback
  local original_once_for_edit = timers.once
  local original_schedule_wrap_for_edit = vim.schedule_wrap
  vim.api.nvim_set_hl(0, preview_name, { fg = '#111111' })
  vim.schedule_wrap = function(callback)
    return callback
  end
  timers.once = function(_, callback)
    edited_timer_callback = callback
    return {
      stop = function() end,
      close = function() end,
    }
  end
  preview.flash_current(flash_instance)
  vim.api.nvim_set_hl(0, preview_name, { fg = '#222222' })
  edited_timer_callback()
  timers.once = original_once_for_edit
  vim.schedule_wrap = original_schedule_wrap_for_edit
  local edited_preview_hl = vim.api.nvim_get_hl(0, { name = preview_name })
  h.assert_equal(edited_preview_hl.fg, 0x222222, 'preview timeout overwrote a later highlight edit', scope)
  h.assert_true(flash_instance.state.preview.name == nil, 'completed edited preview kept highlight state', scope)

  vim.api.nvim_set_hl(0, preview_name, { fg = '#111111' })
  preview.flash_current(flash_instance)
  local restore_failed_set_hl = vim.api.nvim_set_hl
  vim.api.nvim_set_hl = function()
    error('preview restore failed')
  end
  preview.cleanup(flash_instance)
  vim.api.nvim_set_hl = restore_failed_set_hl
  h.assert_equal(
    flash_instance.state.preview.name,
    preview_name,
    'failed preview cleanup dropped highlight name',
    scope
  )
  h.assert_true(type(flash_instance.state.preview.spec) == 'table', 'failed preview cleanup dropped spec', scope)
  preview.cleanup(flash_instance)
  local retry_restored_hl = vim.api.nvim_get_hl(0, { name = preview_name })
  h.assert_equal(retry_restored_hl.fg, 0x111111, 'preview cleanup could not retry failed restore', scope)

  local failed_capture_name = 'HlcraftUiPreviewFailedCapture'
  vim.api.nvim_set_hl(0, failed_capture_name, { fg = '#444444' })
  local failed_capture_instance = {
    state = {
      preview = ui_state.preview(),
      results = {
        { name = failed_capture_name },
      },
      list_cursor = 1,
    },
  }
  local original_get_hl = vim.api.nvim_get_hl
  local failed_capture_set_hl = vim.api.nvim_set_hl
  local get_hl_calls = 0
  local set_hl_calls = 0
  vim.api.nvim_get_hl = function(...)
    get_hl_calls = get_hl_calls + 1
    if get_hl_calls == 2 then
      error('preview flash capture failed')
    end
    return original_get_hl(...)
  end
  vim.api.nvim_set_hl = function(...)
    set_hl_calls = set_hl_calls + 1
    if set_hl_calls == 2 then
      error('preview flash rollback failed')
    end
    return failed_capture_set_hl(...)
  end
  h.with_notify_stub(function()
    preview.flash_current(failed_capture_instance)
  end)
  vim.api.nvim_get_hl = original_get_hl
  vim.api.nvim_set_hl = failed_capture_set_hl
  local failed_capture_kept_name = failed_capture_instance.state.preview.name
  local failed_capture_retry_ok = preview.cleanup(failed_capture_instance)
  local failed_capture_restored = vim.api.nvim_get_hl(0, { name = failed_capture_name })
  if failed_capture_restored.fg ~= 0x444444 then
    vim.api.nvim_set_hl(0, failed_capture_name, { fg = '#444444' })
  end
  h.assert_equal(
    failed_capture_kept_name,
    failed_capture_name,
    'failed preview flash capture dropped restorable highlight state',
    scope
  )
  h.assert_true(failed_capture_retry_ok, 'failed preview flash capture could not retry cleanup', scope)
  h.assert_equal(failed_capture_restored.fg, 0x444444, 'preview flash capture retry restored wrong color', scope)

  local failed_flash_name = 'HlcraftUiPreviewFailedFlash'
  vim.api.nvim_set_hl(0, failed_flash_name, { fg = '#222222' })
  local failed_flash_instance = {
    state = {
      preview = ui_state.preview(),
      results = {
        { name = failed_flash_name },
      },
      list_cursor = 1,
    },
  }
  local original_set_hl = vim.api.nvim_set_hl
  local original_once = timers.once
  vim.api.nvim_set_hl = function()
    error('preview flash failed')
  end
  timers.once = function()
    return {
      stop = function() end,
      close = function() end,
    }
  end
  preview.flash_current(failed_flash_instance)
  vim.api.nvim_set_hl = original_set_hl
  timers.once = original_once
  h.assert_true(failed_flash_instance.state.preview.name == nil, 'failed preview flash kept highlight name', scope)
  h.assert_true(failed_flash_instance.state.preview.spec == nil, 'failed preview flash kept highlight spec', scope)
  h.assert_true(failed_flash_instance.state.preview.timer == nil, 'failed preview flash kept timer', scope)
end, debug.traceback)

pcall(vim.keymap.del, 'n', lhs)
config.setup({})

if not ok then
  error(err, 0)
end

print('hlcraft ui preview: OK')
