local h = require('tests.helpers')
local scope = 'hlcraft ui unsaved prompt'

local prompt = require('hlcraft.ui.scene.unsaved_prompt')

local assert_fails = h.scoped_assert_fails(scope)

local function keymap_callback(buf, lhs)
  for _, item in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
    if item.lhs == lhs then
      return item.callback
    end
  end
  return nil
end

local function with_session_stub(session_stub, run)
  local prompt_module = 'hlcraft.ui.scene.unsaved_prompt'
  local session_module = 'hlcraft.ui.session'
  local original_prompt_module = package.loaded[prompt_module]
  local original_session_module = package.loaded[session_module]

  package.loaded[prompt_module] = nil
  package.loaded[session_module] = session_stub
  local loaded_prompt = require(prompt_module)

  local ok, err = xpcall(function()
    run(loaded_prompt)
  end, debug.traceback)

  package.loaded[prompt_module] = original_prompt_module
  package.loaded[session_module] = original_session_module
  prompt = original_prompt_module

  if not ok then
    error(err, 0)
  end
end

assert_fails(function()
  prompt.close(nil)
end, 'unsaved prompt close accepted missing instance')
local missing_prompt_state_ok = pcall(prompt.close, {
  state = {},
})
h.assert_true(not missing_prompt_state_ok, 'unsaved prompt accepted missing state schema', scope)
assert_fails(function()
  prompt.open({
    ns = false,
    state = {
      unsaved_prompt = {},
    },
  }, 'HlcraftUiUnsavedPrompt', function() end)
end, 'unsaved prompt accepted invalid namespace')
assert_fails(function()
  prompt.open({
    state = {
      unsaved_prompt = {},
    },
  }, '', function() end)
end, 'unsaved prompt accepted empty name')
local spaced_name_instance = {
  state = {
    unsaved_prompt = {},
  },
}
local spaced_name_ok = pcall(prompt.open, spaced_name_instance, 'Bad Name', function() end)
if spaced_name_ok then
  prompt.close(spaced_name_instance)
end
h.assert_true(not spaced_name_ok, 'unsaved prompt accepted whitespace in name', scope)
assert_fails(function()
  prompt.open({
    state = {
      unsaved_prompt = {},
    },
  }, 'HlcraftUiUnsavedPrompt', nil)
end, 'unsaved prompt accepted missing callback')

local failing_buffer_instance = {
  state = {
    unsaved_prompt = {},
  },
}
local buffers_before_buffer_failure = {}
for _, listed_buf in ipairs(vim.api.nvim_list_bufs()) do
  buffers_before_buffer_failure[listed_buf] = true
end
local original_buf_set_lines = vim.api.nvim_buf_set_lines
vim.api.nvim_buf_set_lines = function()
  error('prompt buffer write failed')
end
local failing_buffer_ok = pcall(prompt.open, failing_buffer_instance, 'HlcraftUiUnsavedPrompt', function() end)
vim.api.nvim_buf_set_lines = original_buf_set_lines
h.assert_true(not failing_buffer_ok, 'unsaved prompt accepted failed buffer initialization', scope)
h.assert_true(
  failing_buffer_instance.state.unsaved_prompt.buf == nil,
  'failed prompt buffer initialization kept buffer state',
  scope
)
h.assert_true(
  failing_buffer_instance.state.unsaved_prompt.win == nil,
  'failed prompt buffer initialization kept window state',
  scope
)
for _, listed_buf in ipairs(vim.api.nvim_list_bufs()) do
  h.assert_true(
    buffers_before_buffer_failure[listed_buf] or not vim.api.nvim_buf_is_valid(listed_buf),
    'failed prompt buffer initialization leaked a buffer',
    scope
  )
end

local buffer_cleanup_failure_instance = {
  state = {
    unsaved_prompt = {},
  },
}
local buffer_cleanup_failure_buf
local original_buffer_failure_buf_delete = vim.api.nvim_buf_delete
vim.api.nvim_buf_set_lines = function(buf)
  buffer_cleanup_failure_buf = buf
  error('prompt buffer write failed')
end
vim.api.nvim_buf_delete = function(buf, ...)
  if buf == buffer_cleanup_failure_buf then
    error('prompt buffer delete failed')
  end
  return original_buffer_failure_buf_delete(buf, ...)
end
local buffer_cleanup_failure_ok, buffer_cleanup_failure_err = pcall(
  prompt.open,
  buffer_cleanup_failure_instance,
  'HlcraftUiUnsavedPrompt',
  function() end
)
vim.api.nvim_buf_set_lines = original_buf_set_lines
vim.api.nvim_buf_delete = original_buffer_failure_buf_delete
local buffer_cleanup_kept_buf = buffer_cleanup_failure_instance.state.unsaved_prompt.buf
local buffer_cleanup_buf_valid = buffer_cleanup_failure_buf ~= nil
  and vim.api.nvim_buf_is_valid(buffer_cleanup_failure_buf)
if buffer_cleanup_buf_valid then
  vim.api.nvim_buf_delete(buffer_cleanup_failure_buf, { force = true })
end
h.assert_true(not buffer_cleanup_failure_ok, 'unsaved prompt accepted failed buffer cleanup', scope)
h.assert_true(buffer_cleanup_buf_valid, 'prompt buffer cleanup failure did not preserve its fixture', scope)
h.assert_equal(
  buffer_cleanup_kept_buf,
  buffer_cleanup_failure_buf,
  'failed prompt buffer cleanup dropped the live buffer handle',
  scope
)
h.assert_true(
  tostring(buffer_cleanup_failure_err):find('prompt buffer delete failed', 1, true) ~= nil,
  'failed prompt buffer initialization did not report cleanup failure',
  scope
)

local failing_keymap_instance = {
  state = {
    unsaved_prompt = {},
  },
}
local original_keymap_set = vim.keymap.set
local buffers_before_keymap_failure = {}
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  buffers_before_keymap_failure[buf] = true
end
local windows_before_keymap_failure = {}
for _, win in ipairs(vim.api.nvim_list_wins()) do
  windows_before_keymap_failure[win] = true
end
vim.keymap.set = function()
  error('keymap failed')
end
local failing_keymap_ok = pcall(prompt.open, failing_keymap_instance, 'HlcraftUiUnsavedPrompt', function() end)
vim.keymap.set = original_keymap_set
h.assert_true(not failing_keymap_ok, 'unsaved prompt accepted failed keymap install', scope)
h.assert_true(
  failing_keymap_instance.state.unsaved_prompt.buf == nil,
  'failed unsaved prompt open kept buffer state',
  scope
)
h.assert_true(
  failing_keymap_instance.state.unsaved_prompt.win == nil,
  'failed unsaved prompt open kept window state',
  scope
)
for _, win in ipairs(vim.api.nvim_list_wins()) do
  h.assert_true(windows_before_keymap_failure[win], 'failed unsaved prompt open leaked a window', scope)
end
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  h.assert_true(
    buffers_before_keymap_failure[buf] or not vim.api.nvim_buf_is_valid(buf),
    'failed unsaved prompt open leaked a buffer',
    scope
  )
end

local failed_cleanup_instance = {
  state = {
    unsaved_prompt = {},
  },
}
original_keymap_set = vim.keymap.set
local failed_cleanup_win_close = vim.api.nvim_win_close
local failed_cleanup_buf_delete = vim.api.nvim_buf_delete
vim.keymap.set = function()
  error('keymap failed')
end
vim.api.nvim_win_close = function()
  error('prompt close failed')
end
vim.api.nvim_buf_delete = function()
  error('prompt delete failed')
end
local failed_cleanup_ok, failed_cleanup_err = pcall(
  prompt.open,
  failed_cleanup_instance,
  'HlcraftUiUnsavedPrompt',
  function() end
)
vim.keymap.set = original_keymap_set
vim.api.nvim_win_close = failed_cleanup_win_close
vim.api.nvim_buf_delete = failed_cleanup_buf_delete
h.assert_true(not failed_cleanup_ok, 'unsaved prompt accepted failed cleanup after open failure', scope)
h.assert_true(
  failed_cleanup_instance.state.unsaved_prompt.buf ~= nil,
  'failed unsaved prompt cleanup dropped buffer handle',
  scope
)
h.assert_true(
  failed_cleanup_instance.state.unsaved_prompt.win ~= nil,
  'failed unsaved prompt cleanup dropped window handle',
  scope
)
h.assert_true(
  vim.api.nvim_win_is_valid(failed_cleanup_instance.state.unsaved_prompt.win),
  'failed unsaved prompt cleanup did not leave a live window',
  scope
)
h.assert_true(
  tostring(failed_cleanup_err):find('close failed', 1, true) ~= nil
    and tostring(failed_cleanup_err):find('delete failed', 1, true) ~= nil,
  'failed unsaved prompt cleanup did not aggregate cleanup errors',
  scope
)
prompt.close(failed_cleanup_instance)

with_session_stub({
  save = function()
    error('save exploded')
  end,
  discard = function() end,
}, function(throwing_prompt)
  local throwing_instance = {
    state = {
      unsaved_prompt = {},
    },
  }
  throwing_prompt.open(throwing_instance, 'HlcraftUiUnsavedPrompt', function() end)
  local throwing_buf = throwing_instance.state.unsaved_prompt.buf
  local save_callback = keymap_callback(throwing_buf, 's')
  h.assert_true(type(save_callback) == 'function', 'prompt save mapping did not expose a callback', scope)
  local throwing_notifications = {}
  local save_callback_ok = h.with_notify_stub(function()
    return pcall(save_callback)
  end, function(message)
    throwing_notifications[#throwing_notifications + 1] = message
  end)
  h.assert_true(save_callback_ok, 'prompt save callback error escaped the keymap', scope)
  h.assert_true(
    throwing_notifications[1] and throwing_notifications[1]:find('save exploded', 1, true) ~= nil,
    'prompt save callback error was not notified',
    scope
  )
  h.assert_true(vim.api.nvim_buf_is_valid(throwing_buf), 'failed prompt save callback closed the prompt buffer', scope)
  throwing_prompt.close(throwing_instance)
end)

with_session_stub({
  save = function()
    return false, 'refresh failed after save'
  end,
  discard = function() end,
  is_dirty = function()
    return false
  end,
}, function(refresh_failed_prompt)
  local completed = 0
  local refresh_failed_instance = {
    state = {
      unsaved_prompt = {},
    },
  }
  refresh_failed_prompt.open(refresh_failed_instance, 'HlcraftUiUnsavedPrompt', function()
    completed = completed + 1
  end)
  local refresh_failed_buf = refresh_failed_instance.state.unsaved_prompt.buf
  local save_callback = keymap_callback(refresh_failed_buf, 's')
  h.assert_true(
    type(save_callback) == 'function',
    'prompt refresh-failed save mapping did not expose a callback',
    scope
  )
  local notifications = {}
  local callback_ok = h.with_notify_stub(function()
    return pcall(save_callback)
  end, function(message)
    notifications[#notifications + 1] = message
  end)
  h.assert_true(callback_ok, 'prompt refresh-failed save callback error escaped the keymap', scope)
  h.assert_equal(completed, 1, 'prompt refresh-failed save did not complete after persisted save', scope)
  h.assert_true(
    notifications[1] and notifications[1]:find('refresh failed after save', 1, true) ~= nil,
    'prompt refresh-failed save did not notify the refresh error',
    scope
  )
  refresh_failed_prompt.close(refresh_failed_instance)
end)

local instance = {
  ns = vim.api.nvim_create_namespace('hlcraft-ui-unsaved-prompt-test'),
  state = {
    unsaved_prompt = {},
  },
}

prompt.open(instance, 'HlcraftUiUnsavedPrompt', function() end)

local buf = instance.state.unsaved_prompt.buf
local win = instance.state.unsaved_prompt.win
h.assert_true(vim.api.nvim_buf_is_valid(buf), 'prompt buffer was not created', scope)
h.assert_true(vim.api.nvim_win_is_valid(win), 'prompt window was not created', scope)
h.assert_equal(
  table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
  table.concat(prompt.lines, '\n'),
  'prompt lines changed',
  scope
)
h.assert_true(vim.tbl_contains(prompt.lines, '[s] save draft'), 'prompt save keycap line missing', scope)
h.assert_true(vim.tbl_contains(prompt.lines, '[c/q/Esc] cancel'), 'prompt cancel keycap line missing', scope)

local mappings = {}
for _, item in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
  mappings[item.lhs] = true
end
for _, lhs in ipairs({ 's', 'd', 'c', 'q', '<Esc>' }) do
  h.assert_true(mappings[lhs], ('missing prompt mapping %s'):format(lhs), scope)
end

local marks = vim.api.nvim_buf_get_extmarks(buf, instance.ns, 0, -1, { details = true })
h.assert_true(#marks > 0, 'prompt did not apply visual hierarchy highlights', scope)

local cancel_callback = keymap_callback(buf, 'q')
h.assert_true(type(cancel_callback) == 'function', 'prompt cancel mapping did not expose a callback', scope)
local original_win_close = vim.api.nvim_win_close
local original_buf_delete = vim.api.nvim_buf_delete
vim.api.nvim_win_close = function()
  error('prompt close failed')
end
vim.api.nvim_buf_delete = function()
  error('prompt delete failed')
end
local cancel_notifications = {}
local cancel_callback_ok = h.with_notify_stub(function()
  return pcall(cancel_callback)
end, function(message)
  cancel_notifications[#cancel_notifications + 1] = message
end)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
h.assert_true(cancel_callback_ok, 'prompt cancel callback error escaped the keymap', scope)
h.assert_true(
  cancel_notifications[1]
    and cancel_notifications[1]:find('failed to close unsaved prompt', 1, true) ~= nil
    and cancel_notifications[1]:find('prompt close failed', 1, true) ~= nil
    and cancel_notifications[1]:find('prompt delete failed', 1, true) ~= nil,
  'prompt cancel callback close failure was not notified',
  scope
)
h.assert_equal(instance.state.unsaved_prompt.buf, buf, 'failed prompt cancel dropped buffer handle', scope)
h.assert_equal(instance.state.unsaved_prompt.win, win, 'failed prompt cancel dropped window handle', scope)

vim.api.nvim_win_close = function()
  error('prompt close failed')
end
vim.api.nvim_buf_delete = function()
  error('prompt delete failed')
end
local failed_close_result, failed_close_err = prompt.close(instance)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
h.assert_true(not failed_close_result, 'unsaved prompt close reported success after failed cleanup', scope)
h.assert_true(
  tostring(failed_close_err):find('prompt close failed', 1, true) ~= nil
    and tostring(failed_close_err):find('prompt delete failed', 1, true) ~= nil,
  'unsaved prompt close did not aggregate cleanup errors',
  scope
)
h.assert_equal(instance.state.unsaved_prompt.buf, buf, 'failed prompt close dropped buffer handle', scope)
h.assert_equal(instance.state.unsaved_prompt.win, win, 'failed prompt close dropped window handle', scope)
h.assert_true(vim.api.nvim_win_is_valid(win), 'failed prompt close invalidated test window', scope)

vim.api.nvim_win_close = function()
  error('prompt close failed')
end
vim.api.nvim_buf_delete = function()
  error('prompt delete failed')
end
local reopen_ok = pcall(prompt.open, instance, 'HlcraftUiUnsavedPrompt', function() end)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
h.assert_true(not reopen_ok, 'unsaved prompt reopened after failed previous close', scope)
h.assert_equal(instance.state.unsaved_prompt.buf, buf, 'failed prompt reopen replaced buffer handle', scope)
h.assert_equal(instance.state.unsaved_prompt.win, win, 'failed prompt reopen replaced window handle', scope)

prompt.close(instance)
h.assert_true(instance.state.unsaved_prompt.buf == nil, 'prompt buffer handle was not cleared', scope)
h.assert_true(instance.state.unsaved_prompt.win == nil, 'prompt window handle was not cleared', scope)
h.assert_true(not vim.api.nvim_buf_is_valid(buf), 'prompt buffer was not deleted', scope)

print('hlcraft ui unsaved prompt: OK')
