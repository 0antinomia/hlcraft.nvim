local h = require('tests.helpers')
local scope = 'hlcraft ui workspace window'

local window = require('hlcraft.ui.workspace.window')
local window_options = require('hlcraft.ui.window_options')

local win = vim.api.nvim_get_current_win()
local original = window_options.snapshot(win)

local function restore_original()
  window_options.restore(original)
end

local assert_fails = h.scoped_assert_fails(scope)

local ok, err = xpcall(function()
  vim.wo[win].number = true
  vim.wo[win].relativenumber = true
  vim.wo[win].signcolumn = 'yes'
  vim.wo[win].foldcolumn = '1'

  local instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-workspace-window-test'),
    state = {
      workspace_win_options = {},
      last_workspace_win = nil,
    },
  }

  h.assert_true(window.get_win(instance) == nil, 'workspace get_win returned a missing buffer window', scope)
  assert_fails(function()
    window.get_win(nil)
  end, 'workspace get_win accepted missing instance')
  assert_fails(function()
    window.is_open({ state = false })
  end, 'workspace is_open accepted invalid state')
  assert_fails(function()
    window.apply_window_options(nil, win)
  end, 'workspace option apply accepted missing instance')
  assert_fails(function()
    window.apply_window_options(instance, nil)
  end, 'workspace option apply accepted invalid window')

  window.capture_workspace_window(instance, win)
  h.assert_true(
    window_options.matches_workspace(window_options.read(win)),
    'workspace capture did not apply workspace window options',
    scope
  )
  h.assert_true(instance.state.workspace_win_options[win] ~= nil, 'workspace capture did not snapshot window', scope)
  h.assert_equal(instance.state.last_workspace_win, win, 'workspace capture did not remember last window', scope)

  window.release_workspace_window(instance, win)
  h.assert_true(vim.wo[win].number, 'workspace release did not restore number', scope)
  h.assert_true(vim.wo[win].relativenumber, 'workspace release did not restore relativenumber', scope)
  h.assert_equal(vim.wo[win].signcolumn, 'yes', 'workspace release did not restore signcolumn', scope)
  h.assert_equal(vim.wo[win].foldcolumn, '1', 'workspace release did not restore foldcolumn', scope)
  h.assert_true(instance.state.workspace_win_options[win] == nil, 'workspace release kept window snapshot', scope)
  h.assert_true(instance.state.last_workspace_win == nil, 'workspace release kept last window', scope)

  vim.wo[win].number = true
  vim.wo[win].relativenumber = true
  vim.wo[win].signcolumn = 'yes'
  vim.wo[win].foldcolumn = '1'
  local failed_capture_instance = {
    ns = false,
    state = {
      workspace_win_options = {},
      last_workspace_win = nil,
    },
  }
  local failed_capture_ok = pcall(window.capture_workspace_window, failed_capture_instance, win)
  h.assert_true(not failed_capture_ok, 'workspace capture accepted failed option apply', scope)
  h.assert_true(
    failed_capture_instance.state.workspace_win_options[win] == nil,
    'failed workspace capture kept window snapshot',
    scope
  )
  h.assert_true(
    failed_capture_instance.state.last_workspace_win == nil,
    'failed workspace capture kept last window',
    scope
  )
  h.assert_true(vim.wo[win].number, 'failed workspace capture changed number', scope)
  h.assert_true(vim.wo[win].relativenumber, 'failed workspace capture changed relativenumber', scope)
  h.assert_equal(vim.wo[win].signcolumn, 'yes', 'failed workspace capture changed signcolumn', scope)
  h.assert_equal(vim.wo[win].foldcolumn, '1', 'failed workspace capture changed foldcolumn', scope)

  vim.wo[win].number = true
  vim.wo[win].relativenumber = true
  vim.wo[win].signcolumn = 'yes'
  vim.wo[win].foldcolumn = '1'
  instance.state.origin_win = win
  instance.state.origin_win_options = window_options.snapshot(win)

  window.capture_workspace_window(instance, win)
  h.assert_true(
    window_options.matches_workspace(window_options.read(win)),
    'origin capture did not apply workspace window options',
    scope
  )
  h.assert_true(
    instance.state.workspace_win_options[win] == nil,
    'origin capture should not create workspace snapshot',
    scope
  )

  window.release_workspace_window(instance, win)
  h.assert_true(vim.wo[win].number, 'origin release did not restore number', scope)
  h.assert_true(instance.state.origin_win_options ~= nil, 'origin release cleared reusable origin snapshot', scope)

  local missing_origin_snapshot_instance = {
    ns = instance.ns,
    state = {
      origin_win = win,
      origin_buf = vim.api.nvim_win_get_buf(win),
      origin_win_options = nil,
      workspace_win_options = {},
      last_workspace_win = nil,
    },
  }
  vim.wo[win].number = true
  vim.wo[win].relativenumber = true
  vim.wo[win].signcolumn = 'yes'
  vim.wo[win].foldcolumn = '1'
  window.capture_workspace_window(missing_origin_snapshot_instance, win)
  h.assert_true(
    missing_origin_snapshot_instance.state.origin_win_options ~= nil,
    'origin capture without snapshot did not capture original options',
    scope
  )
  window.release_workspace_window(missing_origin_snapshot_instance, win)
  h.assert_true(vim.wo[win].number, 'origin release without initial snapshot did not restore number', scope)
  h.assert_true(
    vim.wo[win].relativenumber,
    'origin release without initial snapshot did not restore relativenumber',
    scope
  )
  h.assert_equal(
    vim.wo[win].signcolumn,
    'yes',
    'origin release without initial snapshot did not restore signcolumn',
    scope
  )
  h.assert_equal(
    vim.wo[win].foldcolumn,
    '1',
    'origin release without initial snapshot did not restore foldcolumn',
    scope
  )

  local origin_close_failure_win = vim.api.nvim_get_current_win()
  local origin_close_failure_buf = vim.api.nvim_get_current_buf()
  local workspace_close_failure_buf = vim.api.nvim_create_buf(false, true)
  vim.cmd('vsplit')
  local workspace_close_failure_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(workspace_close_failure_win, workspace_close_failure_buf)
  local origin_close_failure_instance = {
    ns = instance.ns,
    state = {
      buf = workspace_close_failure_buf,
      origin_win = origin_close_failure_win,
      origin_buf = origin_close_failure_buf,
      origin_win_options = window_options.snapshot(origin_close_failure_win),
      workspace_win_options = {},
      last_workspace_win = workspace_close_failure_win,
    },
  }
  window.capture_workspace_window(origin_close_failure_instance, workspace_close_failure_win)
  local original_win_close = vim.api.nvim_win_close
  vim.api.nvim_win_close = function(target_win, ...)
    if target_win == workspace_close_failure_win then
      error('workspace close failed')
    end
    return original_win_close(target_win, ...)
  end
  local origin_restore_ok
  local origin_close_stub_ok, origin_close_stub_err = xpcall(function()
    origin_restore_ok = window.restore_origin(origin_close_failure_instance)
  end, debug.traceback)
  vim.api.nvim_win_close = original_win_close
  if not origin_close_stub_ok then
    error(origin_close_stub_err, 0)
  end
  h.assert_true(origin_restore_ok == false, 'workspace origin restore ignored failed workspace close', scope)
  h.assert_true(
    vim.api.nvim_win_is_valid(workspace_close_failure_win),
    'failed origin restore invalidated workspace window',
    scope
  )
  if vim.api.nvim_win_is_valid(workspace_close_failure_win) then
    vim.api.nvim_win_close(workspace_close_failure_win, true)
  end
  if vim.api.nvim_buf_is_valid(workspace_close_failure_buf) then
    vim.api.nvim_buf_delete(workspace_close_failure_buf, { force = true })
  end
  if vim.api.nvim_win_is_valid(origin_close_failure_win) then
    vim.api.nvim_set_current_win(origin_close_failure_win)
  end

  local option_restore_failure_origin_win = vim.api.nvim_get_current_win()
  local option_restore_failure_origin_buf = vim.api.nvim_get_current_buf()
  local option_restore_failure_workspace_buf = vim.api.nvim_create_buf(false, true)
  vim.cmd('vsplit')
  local option_restore_failure_workspace_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(option_restore_failure_workspace_win, option_restore_failure_workspace_buf)
  local option_restore_failure_instance = {
    state = {
      buf = option_restore_failure_workspace_buf,
      origin_win = option_restore_failure_origin_win,
      origin_buf = option_restore_failure_origin_buf,
      origin_win_options = nil,
      workspace_win_options = {
        [option_restore_failure_workspace_win] = {
          label = 'workspace',
        },
      },
      last_workspace_win = option_restore_failure_workspace_win,
    },
  }
  local option_restore_original_restore = window_options.restore
  window_options.restore = function(snapshot)
    if snapshot.label == 'workspace' then
      return false
    end
    return option_restore_original_restore(snapshot)
  end
  local option_restore_origin_ok
  local option_restore_stub_ok, option_restore_stub_err = xpcall(function()
    option_restore_origin_ok = window.restore_origin(option_restore_failure_instance)
  end, debug.traceback)
  window_options.restore = option_restore_original_restore
  if not option_restore_stub_ok then
    error(option_restore_stub_err, 0)
  end
  h.assert_true(
    option_restore_origin_ok == false,
    'workspace origin restore ignored failed workspace option restore',
    scope
  )
  if vim.api.nvim_win_is_valid(option_restore_failure_workspace_win) then
    vim.api.nvim_win_close(option_restore_failure_workspace_win, true)
  end
  if vim.api.nvim_buf_is_valid(option_restore_failure_workspace_buf) then
    vim.api.nvim_buf_delete(option_restore_failure_workspace_buf, { force = true })
  end
  if vim.api.nvim_win_is_valid(option_restore_failure_origin_win) then
    vim.api.nvim_set_current_win(option_restore_failure_origin_win)
  end

  local invalid_snapshot_ok = pcall(window_options.restore, {
    win = win,
  })
  h.assert_true(not invalid_snapshot_ok, 'window option restore accepted missing values', scope)
  local unmanaged_snapshot_ok = pcall(window_options.restore, {
    win = win,
    values = {
      wrap = false,
    },
  })
  h.assert_true(not unmanaged_snapshot_ok, 'window option restore accepted unmanaged option values', scope)
  local partial_snapshot_ok = pcall(window_options.restore, {
    win = win,
    values = {
      number = true,
      relativenumber = true,
      signcolumn = 'yes',
    },
  })
  h.assert_true(not partial_snapshot_ok, 'window option restore accepted partial option values', scope)
  vim.wo[win].number = true
  vim.wo[win].relativenumber = true
  vim.wo[win].signcolumn = 'yes'
  vim.wo[win].foldcolumn = '1'
  local invalid_value_snapshot_ok = pcall(window_options.restore, {
    win = win,
    values = {
      number = false,
      relativenumber = false,
      signcolumn = 'invalid',
      foldcolumn = '0',
    },
  })
  h.assert_true(not invalid_value_snapshot_ok, 'window option restore accepted invalid option value', scope)
  h.assert_true(vim.wo[win].number, 'failed window option restore changed number', scope)
  h.assert_true(vim.wo[win].relativenumber, 'failed window option restore changed relativenumber', scope)
  h.assert_equal(vim.wo[win].signcolumn, 'yes', 'failed window option restore changed signcolumn', scope)
  h.assert_equal(vim.wo[win].foldcolumn, '1', 'failed window option restore changed foldcolumn', scope)
  local original_wo = vim.wo
  local option_values = {
    number = true,
    relativenumber = true,
    signcolumn = 'yes',
    foldcolumn = '1',
  }
  local option_writes = 0
  local option_proxy = setmetatable({}, {
    __index = function(_, option)
      return option_values[option]
    end,
    __newindex = function(_, option, value)
      option_writes = option_writes + 1
      if option_writes == 3 then
        error('window option apply failed')
      end
      if option_writes > 3 and option == 'number' then
        error('window option rollback failed')
      end
      option_values[option] = value
    end,
  })
  vim.wo = setmetatable({}, {
    __index = function(_, target_win)
      if target_win == win then
        return option_proxy
      end
      return original_wo[target_win]
    end,
  })
  local option_rollback_ok, option_rollback_err = pcall(window_options.restore, {
    win = win,
    values = {
      number = false,
      relativenumber = false,
      signcolumn = 'no',
      foldcolumn = '0',
    },
  })
  vim.wo = original_wo
  h.assert_true(not option_rollback_ok, 'window option restore accepted failed rollback', scope)
  h.assert_true(
    tostring(option_rollback_err):find('window option rollback failed', 1, true) ~= nil,
    'window option restore did not report rollback failure',
    scope
  )
  local non_table_snapshot_ok = pcall(window_options.restore, false)
  h.assert_true(not non_table_snapshot_ok, 'window option restore accepted non-table snapshot', scope)
  local invalid_workspace_values_ok = pcall(window_options.matches_workspace, nil)
  h.assert_true(not invalid_workspace_values_ok, 'workspace option matcher accepted nil values', scope)
  local partial_workspace_values_ok = pcall(window_options.matches_workspace, {
    number = false,
    relativenumber = false,
    signcolumn = 'no',
  })
  h.assert_true(not partial_workspace_values_ok, 'workspace option matcher accepted partial values', scope)
  local unmanaged_workspace_values_ok = pcall(window_options.matches_workspace, {
    number = false,
    relativenumber = false,
    signcolumn = 'no',
    foldcolumn = '0',
    wrap = false,
  })
  h.assert_true(not unmanaged_workspace_values_ok, 'workspace option matcher accepted unmanaged values', scope)
  h.assert_true(
    window_options.snapshot(nil) == nil,
    'window option snapshot rejected invalid window incorrectly',
    scope
  )
  assert_fails(function()
    window_options.read(nil)
  end, 'window option read accepted invalid window')
  assert_fails(function()
    window_options.apply(nil, instance.ns)
  end, 'window option apply accepted invalid window')
  assert_fails(function()
    window_options.apply(win, false)
  end, 'window option apply accepted non-numeric namespace')
  assert_fails(function()
    window_options.apply(win, math.huge)
  end, 'window option apply accepted infinite namespace')

  local missing_snapshot_store_ok = pcall(window.restore_all_workspace_windows, {
    state = {},
  })
  h.assert_true(not missing_snapshot_store_ok, 'workspace restore accepted missing snapshot store', scope)
  local original_tbl_keys = vim.tbl_keys
  local original_restore = window_options.restore
  local restored_after_failure = false
  local restore_all_failure_instance = {
    state = {
      workspace_win_options = {
        fail = {
          label = 'fail',
        },
        good = {
          label = 'good',
        },
      },
    },
  }
  vim.tbl_keys = function()
    return { 'fail', 'good' }
  end
  window_options.restore = function(snapshot)
    if snapshot.label == 'fail' then
      error('window restore failed')
    end
    if snapshot.label == 'good' then
      restored_after_failure = true
      return true
    end
    return original_restore(snapshot)
  end
  local restore_all_failure_ok
  local restore_all_stub_ok, restore_all_stub_err = xpcall(function()
    restore_all_failure_ok = pcall(window.restore_all_workspace_windows, restore_all_failure_instance)
  end, debug.traceback)
  vim.tbl_keys = original_tbl_keys
  window_options.restore = original_restore
  if not restore_all_stub_ok then
    error(restore_all_stub_err, 0)
  end
  h.assert_true(not restore_all_failure_ok, 'workspace restore all ignored failed snapshot restore', scope)
  h.assert_true(restored_after_failure, 'workspace restore all stopped after first failed snapshot', scope)
  h.assert_true(
    restore_all_failure_instance.state.workspace_win_options.good == nil,
    'workspace restore all kept successfully restored snapshot after an earlier failure',
    scope
  )
  assert_fails(function()
    window.restore_all_workspace_windows(nil)
  end, 'workspace restore accepted missing instance')
  assert_fails(function()
    window.restore_origin(nil)
  end, 'workspace origin restore accepted missing instance')
  assert_fails(function()
    window.capture_workspace_window(nil, win)
  end, 'workspace capture accepted missing instance')
  assert_fails(function()
    window.release_workspace_window(nil, win)
  end, 'workspace release accepted missing instance')
  h.assert_true(
    pcall(window.capture_workspace_window, instance, nil),
    'workspace capture should ignore invalid window handles',
    scope
  )
  h.assert_true(
    pcall(window.release_workspace_window, instance, nil),
    'workspace release should ignore invalid window handles',
    scope
  )

  window_options.apply(win, instance.ns)
  local invalid_origin_snapshot_ok = pcall(window.capture_workspace_window, {
    ns = instance.ns,
    state = {
      workspace_win_options = {},
      last_workspace_win = nil,
      origin_win_options = {},
    },
  }, win)
  h.assert_true(not invalid_origin_snapshot_ok, 'workspace capture accepted invalid origin snapshot values', scope)
end, debug.traceback)

restore_original()

if not ok then
  error(err, 0)
end

print('hlcraft ui workspace window: OK')
