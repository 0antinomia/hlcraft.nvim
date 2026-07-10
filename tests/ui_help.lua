local h = require('tests.helpers')
local scope = 'hlcraft ui help'

local help = require('hlcraft.ui.help')
local handles = require('hlcraft.ui.handles')
local line_highlights = require('hlcraft.ui.render.line_highlights')

local assert_fails = h.scoped_assert_fails(scope)

local function keymap_callback(buf, lhs)
  for _, item in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
    if item.lhs == lhs then
      return item.callback
    end
  end
  return nil
end

local instance = {
  ns = vim.api.nvim_create_namespace('hlcraft-ui-help-test'),
  state = {
    help_buf = nil,
    help_win = nil,
  },
}

local ok, err = xpcall(function()
  h.assert_true(not help.is_open(instance), 'fresh help window reported open', scope)
  assert_fails(function()
    help.is_open(nil)
  end, 'help is_open accepted missing instance')
  assert_fails(function()
    help.ensure_buffer(nil)
  end, 'help ensure_buffer accepted missing instance')
  assert_fails(function()
    help.close(nil)
  end, 'help close accepted missing instance')
  assert_fails(function()
    help.delete_buffer(nil)
  end, 'help delete_buffer accepted missing instance')
  assert_fails(function()
    help.toggle({
      ns = false,
      state = {},
    })
  end, 'help toggle accepted invalid namespace')

  local buf = help.ensure_buffer(instance)
  h.assert_true(handles.is_valid_buf(buf), 'help buffer was not created', scope)
  h.assert_equal(instance.state.help_buf, buf, 'help buffer handle was not stored', scope)
  h.assert_equal(help.ensure_buffer(instance), buf, 'help buffer was not reused', scope)

  local reusable_help_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local original_buf_set_lines = vim.api.nvim_buf_set_lines
  local refresh_set_calls = 0
  vim.api.nvim_buf_set_lines = function()
    refresh_set_calls = refresh_set_calls + 1
    error(refresh_set_calls == 1 and 'help refresh failed' or 'help refresh rollback failed')
  end
  local refresh_failure_ok, refresh_failure_err = pcall(help.ensure_buffer, instance)
  vim.api.nvim_buf_set_lines = original_buf_set_lines
  h.assert_true(not refresh_failure_ok, 'help accepted failed buffer refresh', scope)
  h.assert_true(
    tostring(refresh_failure_err):find('help refresh rollback failed', 1, true) ~= nil,
    'failed help refresh did not report line restore failure',
    scope
  )
  h.assert_equal(instance.state.help_buf, buf, 'failed help refresh changed buffer state', scope)
  h.assert_true(handles.is_valid_buf(buf), 'failed help refresh invalidated buffer', scope)
  h.assert_true(not vim.bo[buf].modifiable, 'failed help refresh left buffer modifiable', scope)
  h.assert_equal(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
    table.concat(reusable_help_lines, '\n'),
    'failed help refresh changed buffer lines',
    scope
  )

  local failing_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-help-keymap-failure-test'),
    state = {
      help_buf = nil,
      help_win = nil,
    },
  }
  local buffers_before_keymap_failure = {}
  for _, listed_buf in ipairs(vim.api.nvim_list_bufs()) do
    buffers_before_keymap_failure[listed_buf] = true
  end
  local original_keymap_set = vim.keymap.set
  vim.keymap.set = function()
    error('help keymap failed')
  end
  local failing_keymap_ok = pcall(help.ensure_buffer, failing_instance)
  vim.keymap.set = original_keymap_set
  h.assert_true(not failing_keymap_ok, 'help accepted failed keymap install', scope)
  h.assert_true(failing_instance.state.help_buf == nil, 'failed help keymap install kept buffer state', scope)
  for _, listed_buf in ipairs(vim.api.nvim_list_bufs()) do
    h.assert_true(
      buffers_before_keymap_failure[listed_buf] or not vim.api.nvim_buf_is_valid(listed_buf),
      'failed help keymap install leaked a buffer',
      scope
    )
  end

  local keymap_delete_failure_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-help-keymap-delete-failure-test'),
    state = {
      help_buf = nil,
      help_win = nil,
    },
  }
  local keymap_delete_failure_buf
  original_keymap_set = vim.keymap.set
  local original_keymap_failure_buf_delete = vim.api.nvim_buf_delete
  vim.keymap.set = function()
    error('help keymap failed')
  end
  vim.api.nvim_buf_delete = function(target_buf, ...)
    keymap_delete_failure_buf = target_buf
    error('help buffer delete failed')
  end
  local keymap_delete_failure_ok, keymap_delete_failure_err = pcall(help.ensure_buffer, keymap_delete_failure_instance)
  vim.keymap.set = original_keymap_set
  vim.api.nvim_buf_delete = original_keymap_failure_buf_delete
  local keymap_delete_kept_buf = keymap_delete_failure_instance.state.help_buf
  local keymap_delete_buf_valid = keymap_delete_failure_buf ~= nil and handles.is_valid_buf(keymap_delete_failure_buf)
  if keymap_delete_buf_valid then
    vim.api.nvim_buf_delete(keymap_delete_failure_buf, { force = true })
  end
  h.assert_true(not keymap_delete_failure_ok, 'help accepted failed keymap install after failed cleanup', scope)
  h.assert_true(keymap_delete_buf_valid, 'help keymap cleanup failure test did not preserve a buffer', scope)
  h.assert_equal(
    keymap_delete_kept_buf,
    keymap_delete_failure_buf,
    'delete-failed help buffer setup dropped the leaked buffer handle',
    scope
  )
  h.assert_true(
    tostring(keymap_delete_failure_err):find('help buffer delete failed', 1, true) ~= nil,
    'delete-failed help buffer setup did not report the cleanup error',
    scope
  )

  local failing_toggle_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-help-open-failure-test'),
    state = {
      help_buf = nil,
      help_win = nil,
    },
  }
  local windows_before_toggle_failure = {}
  for _, listed_win in ipairs(vim.api.nvim_list_wins()) do
    windows_before_toggle_failure[listed_win] = true
  end
  local original_apply_hint_line = line_highlights.apply_hint_line
  line_highlights.apply_hint_line = function()
    error('help highlight failed')
  end
  local failing_toggle_ok = pcall(help.toggle, failing_toggle_instance)
  line_highlights.apply_hint_line = original_apply_hint_line
  h.assert_true(not failing_toggle_ok, 'help accepted failed window decoration', scope)
  h.assert_true(failing_toggle_instance.state.help_win == nil, 'failed help toggle kept window state', scope)
  for _, listed_win in ipairs(vim.api.nvim_list_wins()) do
    h.assert_true(windows_before_toggle_failure[listed_win], 'failed help toggle leaked a window', scope)
  end
  help.delete_buffer(failing_toggle_instance)

  local toggle_close_failure_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-help-toggle-close-failure-test'),
    state = {
      help_buf = nil,
      help_win = nil,
    },
  }
  local toggle_close_failure_win
  original_apply_hint_line = line_highlights.apply_hint_line
  local original_toggle_failure_win_close = vim.api.nvim_win_close
  line_highlights.apply_hint_line = function()
    error('help highlight failed')
  end
  vim.api.nvim_win_close = function(target_win, ...)
    toggle_close_failure_win = target_win
    error('help window close failed')
  end
  local toggle_close_failure_ok, toggle_close_failure_err = pcall(help.toggle, toggle_close_failure_instance)
  line_highlights.apply_hint_line = original_apply_hint_line
  vim.api.nvim_win_close = original_toggle_failure_win_close
  local toggle_close_kept_win = toggle_close_failure_instance.state.help_win
  local toggle_close_win_valid = toggle_close_failure_win ~= nil and handles.is_valid_win(toggle_close_failure_win)
  if toggle_close_win_valid then
    vim.api.nvim_win_close(toggle_close_failure_win, true)
  end
  help.delete_buffer(toggle_close_failure_instance)
  h.assert_true(not toggle_close_failure_ok, 'help accepted failed decoration after failed cleanup', scope)
  h.assert_true(toggle_close_win_valid, 'help window cleanup failure test did not preserve a window', scope)
  h.assert_equal(
    toggle_close_kept_win,
    toggle_close_failure_win,
    'close-failed help toggle dropped the leaked window handle',
    scope
  )
  h.assert_true(
    tostring(toggle_close_failure_err):find('help window close failed', 1, true) ~= nil,
    'close-failed help toggle did not report the cleanup error',
    scope
  )

  help.toggle(instance)
  h.assert_true(help.is_open(instance), 'help toggle did not open window', scope)
  h.assert_true(handles.is_valid_win(instance.state.help_win), 'help window handle is invalid', scope)
  h.assert_equal(vim.api.nvim_win_get_buf(instance.state.help_win), buf, 'help window opened the wrong buffer', scope)

  local open_help_win = instance.state.help_win
  local close_callback = keymap_callback(buf, 'q')
  h.assert_true(type(close_callback) == 'function', 'help close mapping did not expose a callback', scope)
  local original_win_close = vim.api.nvim_win_close
  vim.api.nvim_win_close = function()
    error('help close failed')
  end
  local close_notifications = {}
  local close_callback_ok = h.with_notify_stub(function()
    return pcall(close_callback)
  end, function(message)
    close_notifications[#close_notifications + 1] = message
  end)
  vim.api.nvim_win_close = original_win_close
  h.assert_true(close_callback_ok, 'help close callback error escaped the keymap', scope)
  h.assert_true(
    close_notifications[1]
      and close_notifications[1]:find('failed to close help window', 1, true) ~= nil
      and close_notifications[1]:find('help close failed', 1, true) ~= nil,
    'help close callback failure was not notified',
    scope
  )
  h.assert_equal(instance.state.help_win, open_help_win, 'failed help close callback dropped window handle', scope)

  vim.api.nvim_win_close = function()
    error('help close failed')
  end
  local failed_close_result, failed_close_err = help.close(instance)
  vim.api.nvim_win_close = original_win_close
  h.assert_true(not failed_close_result, 'help close reported success after failed cleanup', scope)
  h.assert_true(
    tostring(failed_close_err):find('help close failed', 1, true) ~= nil,
    'help close did not return the cleanup error',
    scope
  )
  h.assert_equal(instance.state.help_win, open_help_win, 'failed help close dropped window handle', scope)
  h.assert_true(handles.is_valid_win(open_help_win), 'failed help close invalidated test window', scope)
  help.close(instance)
  h.assert_true(instance.state.help_win == nil, 'help close retry kept window handle', scope)

  local delete_failure_buf = help.ensure_buffer(instance)
  local original_buf_delete = vim.api.nvim_buf_delete
  vim.api.nvim_buf_delete = function()
    error('help buffer delete failed')
  end
  local failed_delete_result, failed_delete_err = help.delete_buffer(instance)
  vim.api.nvim_buf_delete = original_buf_delete
  h.assert_true(not failed_delete_result, 'help buffer delete reported success after failed cleanup', scope)
  h.assert_true(
    tostring(failed_delete_err):find('help buffer delete failed', 1, true) ~= nil,
    'help buffer delete did not return the cleanup error',
    scope
  )
  h.assert_equal(instance.state.help_buf, delete_failure_buf, 'failed help delete dropped buffer handle', scope)
  h.assert_true(handles.is_valid_buf(delete_failure_buf), 'failed help delete invalidated test buffer', scope)
  help.delete_buffer(instance)
  h.assert_true(instance.state.help_buf == nil, 'help delete retry kept buffer handle', scope)

  help.toggle(instance)
  h.assert_true(help.is_open(instance), 'help toggle did not reopen window', scope)
  help.toggle(instance)
  h.assert_true(not help.is_open(instance), 'help toggle did not close window', scope)
  h.assert_true(instance.state.help_win == nil, 'help close kept window handle', scope)

  help.delete_buffer(instance)
  h.assert_true(instance.state.help_buf == nil, 'help delete kept buffer handle', scope)
end, debug.traceback)

help.close(instance)
help.delete_buffer(instance)

if not ok then
  error(err, 0)
end

print('hlcraft ui help: OK')
