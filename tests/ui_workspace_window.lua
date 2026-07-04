local h = require('tests.helpers')
local scope = 'hlcraft ui workspace window'

local window = require('hlcraft.ui.workspace.window')
local window_options = require('hlcraft.ui.window_options')

local win = vim.api.nvim_get_current_win()
local original = window_options.snapshot(win)

local function restore_original()
  window_options.restore(original)
end

local function assert_fails(fn, message)
  h.assert_true(not pcall(fn), message, scope)
end

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

  local invalid_snapshot_ok = pcall(window_options.restore, {
    win = win,
  })
  h.assert_true(not invalid_snapshot_ok, 'window option restore accepted missing values', scope)
  local invalid_workspace_values_ok = pcall(window_options.matches_workspace, nil)
  h.assert_true(not invalid_workspace_values_ok, 'workspace option matcher accepted nil values', scope)

  local missing_snapshot_store_ok = pcall(window.restore_all_workspace_windows, {
    state = {},
  })
  h.assert_true(not missing_snapshot_store_ok, 'workspace restore accepted missing snapshot store', scope)
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
