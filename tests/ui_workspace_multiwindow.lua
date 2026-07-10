local h = require('tests.helpers')
local scope = 'hlcraft ui workspace multiwindow'

local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local ui_state = require('hlcraft.ui.state')
local window_options = require('hlcraft.ui.window_options')

local function new_instance(name)
  return {
    group_name = name,
    id = name,
    ns = vim.api.nvim_create_namespace(name),
    state = ui_state.initial(),
    rerender = function() end,
    cleanup = function() end,
  }
end

local function close_tab(tab)
  if not vim.api.nvim_tabpage_is_valid(tab) then
    return
  end
  vim.api.nvim_set_current_tabpage(tab)
  vim.cmd('tabclose!')
end

do
  vim.cmd('tabnew')
  local tab = vim.api.nvim_get_current_tabpage()
  local instance = new_instance('HlcraftUiWorkspaceReopenVisible')
  local origin_win = vim.api.nvim_get_current_win()
  local origin_buf = vim.api.nvim_get_current_buf()

  lifecycle.open(instance)
  local workspace_win = vim.api.nvim_get_current_win()
  local workspace_buf = instance.state.buf
  local origin_options = vim.deepcopy(instance.state.origin_win_options)

  vim.cmd('vnew')
  local caller_win = vim.api.nvim_get_current_win()
  local caller_buf = vim.api.nvim_get_current_buf()
  lifecycle.open(instance)

  local observed = {
    current_win = vim.api.nvim_get_current_win(),
    caller_buf = vim.api.nvim_win_get_buf(caller_win),
    origin_win = instance.state.origin_win,
    origin_buf = instance.state.origin_buf,
    origin_options = vim.deepcopy(instance.state.origin_win_options),
    workspace_wins = vim.fn.win_findbuf(workspace_buf),
  }

  lifecycle.cleanup(instance)
  close_tab(tab)

  h.assert_equal(observed.current_win, workspace_win, 'reopen did not focus the visible workspace', scope)
  h.assert_equal(observed.caller_buf, caller_buf, 'reopen replaced the caller window buffer', scope)
  h.assert_equal(observed.origin_win, origin_win, 'reopen replaced the original window', scope)
  h.assert_equal(observed.origin_buf, origin_buf, 'reopen replaced the original buffer', scope)
  h.assert_true(
    vim.deep_equal(observed.origin_options, origin_options),
    'reopen replaced the original window options',
    scope
  )
  h.assert_equal(#observed.workspace_wins, 1, 'reopen displayed the workspace in multiple windows', scope)
end

do
  vim.cmd('tabnew')
  local tab = vim.api.nvim_get_current_tabpage()
  local instance = new_instance('HlcraftUiWorkspaceHideAllWindows')
  local origin_win = vim.api.nvim_get_current_win()
  local origin_buf = vim.api.nvim_get_current_buf()
  local origin_options = window_options.snapshot(origin_win)

  lifecycle.open(instance)
  local workspace_buf = instance.state.buf
  vim.cmd('vsplit')
  local retry_win = vim.api.nvim_get_current_win()
  vim.cmd('vsplit')
  local closing_win = vim.api.nvim_get_current_win()

  local original_win_close = vim.api.nvim_win_close
  vim.api.nvim_win_close = function(win, ...)
    if win == retry_win then
      error('workspace close failed')
    end
    return original_win_close(win, ...)
  end

  local notifications = {}
  local hide_ok = h.with_notify_stub(function()
    return lifecycle.hide(instance)
  end, function(message)
    notifications[#notifications + 1] = message
  end)
  vim.api.nvim_win_close = original_win_close

  local observed = {
    hide_ok = hide_ok,
    origin_buf = vim.api.nvim_win_get_buf(origin_win),
    origin_options = window_options.read(origin_win),
    retry_valid = vim.api.nvim_win_is_valid(retry_win),
    closing_valid = vim.api.nvim_win_is_valid(closing_win),
    workspace_wins = vim.fn.win_findbuf(workspace_buf),
    notification = notifications[1],
  }

  lifecycle.hide(instance)
  lifecycle.cleanup(instance)
  close_tab(tab)

  h.assert_true(observed.hide_ok == false, 'multiwindow hide ignored a failed window close', scope)
  h.assert_equal(observed.origin_buf, origin_buf, 'multiwindow hide did not restore the origin buffer', scope)
  h.assert_true(
    vim.deep_equal(observed.origin_options, origin_options.values),
    'multiwindow hide did not restore the origin window options',
    scope
  )
  h.assert_true(observed.retry_valid, 'multiwindow hide invalidated the failed window handle', scope)
  h.assert_true(not observed.closing_valid, 'multiwindow hide stopped before closing another workspace window', scope)
  h.assert_equal(#observed.workspace_wins, 1, 'multiwindow hide left an unreported workspace window', scope)
  h.assert_true(
    observed.notification and observed.notification:find('origin window', 1, true) ~= nil,
    'multiwindow hide did not report the aggregate restore failure',
    scope
  )
end

do
  vim.cmd('tabnew')
  local tab = vim.api.nvim_get_current_tabpage()
  local instance = new_instance('HlcraftUiWorkspaceRestoreDetachedWindow')
  local origin_win = vim.api.nvim_get_current_win()
  local origin_buf = vim.api.nvim_get_current_buf()
  local origin_options = window_options.snapshot(origin_win)
  local workspace_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(origin_win, workspace_buf)

  vim.cmd('vnew')
  local detached_win = vim.api.nvim_get_current_win()
  local detached_options = window_options.snapshot(detached_win)
  window_options.apply(detached_win, instance.ns)
  instance.state.buf = workspace_buf
  instance.state.origin_win = origin_win
  instance.state.origin_buf = origin_buf
  instance.state.origin_win_options = origin_options
  instance.state.workspace_win_options[detached_win] = detached_options
  instance.state.last_workspace_win = detached_win
  vim.api.nvim_set_current_win(origin_win)

  local hide_ok = lifecycle.hide(instance)
  local observed = {
    detached_options = window_options.read(detached_win),
    detached_snapshot = instance.state.workspace_win_options[detached_win],
  }

  lifecycle.cleanup(instance)
  close_tab(tab)

  h.assert_true(hide_ok, 'workspace hide rejected a detached managed window', scope)
  h.assert_true(
    vim.deep_equal(observed.detached_options, detached_options.values),
    'workspace hide did not restore detached window options',
    scope
  )
  h.assert_true(observed.detached_snapshot == nil, 'workspace hide kept a detached window snapshot', scope)
end

print('hlcraft ui workspace multiwindow: OK')
