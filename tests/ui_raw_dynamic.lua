local h = require('tests.helpers')
local scope = 'hlcraft ui raw dynamic'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local engine = require('hlcraft.engine.service')
local raw_dynamic = require('hlcraft.ui.raw_dynamic')

local name = 'HlcraftUiRawDynamicNormal'
local persist_dir = h.temp_dir('hlcraft-ui-raw-dynamic')

local function keymap_callback(buf, lhs)
  for _, item in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
    if item.lhs == lhs then
      return item.callback
    end
  end
  return nil
end

hlcraft.setup({
  persistence = {
    dir = persist_dir,
    reapply_events = {
      enabled = false,
    },
  },
  search = {
    debounce_ms = 0,
  },
})

vim.api.nvim_set_hl(0, name, { fg = '#101010' })
engine.set_group(name, 'ui-raw-dynamic')
local dynamic_ok, dynamic_err = engine.set_dynamic(name, 'fg', {
  version = 1,
  preset = 'manual',
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
    { at = 1, color = '#ffffff' },
  },
})
h.assert_true(dynamic_ok, dynamic_err or 'set dynamic failed', scope)

local result = { name = name }
local instance = { state = {} }

local missing_raw_instance_ok = pcall(raw_dynamic.close, nil)
h.assert_true(not missing_raw_instance_ok, 'raw dynamic close accepted missing instance', scope)
local missing_raw_open_instance_ok = pcall(raw_dynamic.open, nil, result, 'fg')
h.assert_true(not missing_raw_open_instance_ok, 'raw dynamic open accepted missing instance', scope)
local invalid_raw_state_ok = pcall(raw_dynamic.close, {
  state = {
    raw_dynamic = true,
  },
})
h.assert_true(not invalid_raw_state_ok, 'raw dynamic close accepted invalid state schema', scope)
local invalid_raw_buf_ok = pcall(raw_dynamic.close, {
  state = {
    raw_dynamic = {
      buf = false,
    },
  },
})
h.assert_true(not invalid_raw_buf_ok, 'raw dynamic close accepted invalid buffer handle state', scope)
local invalid_raw_win_ok = pcall(raw_dynamic.close, {
  state = {
    raw_dynamic = {
      win = false,
    },
  },
})
h.assert_true(not invalid_raw_win_ok, 'raw dynamic close accepted invalid window handle state', scope)
local invalid_raw_result_ok = pcall(raw_dynamic.open, {
  state = {},
}, {}, 'fg')
h.assert_true(not invalid_raw_result_ok, 'raw dynamic open accepted a nameless result', scope)
local invalid_raw_field_ok = pcall(raw_dynamic.open, {
  state = {},
}, result, false)
h.assert_true(not invalid_raw_field_ok, 'raw dynamic open accepted invalid field', scope)

local failing_keymap_instance = { state = {} }
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
local failing_keymap_ok = pcall(raw_dynamic.open, failing_keymap_instance, result, 'fg')
vim.keymap.set = original_keymap_set
h.assert_true(not failing_keymap_ok, 'raw dynamic open accepted failed keymap install', scope)
local leaked_raw_state = failing_keymap_instance.state.raw_dynamic
h.assert_true(leaked_raw_state == nil, 'failed raw dynamic open kept raw state', scope)
for _, win in ipairs(vim.api.nvim_list_wins()) do
  h.assert_true(windows_before_keymap_failure[win], 'failed raw dynamic open leaked a window', scope)
end
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  h.assert_true(
    buffers_before_keymap_failure[buf] or not vim.api.nvim_buf_is_valid(buf),
    'failed raw dynamic open leaked a buffer',
    scope
  )
end

local failed_cleanup_instance = { state = {} }
original_keymap_set = vim.keymap.set
local failed_cleanup_win_close = vim.api.nvim_win_close
local failed_cleanup_buf_delete = vim.api.nvim_buf_delete
vim.keymap.set = function()
  error('keymap failed')
end
vim.api.nvim_win_close = function()
  error('close failed')
end
vim.api.nvim_buf_delete = function()
  error('delete failed')
end
local failed_cleanup_ok, failed_cleanup_err = pcall(raw_dynamic.open, failed_cleanup_instance, result, 'fg')
vim.keymap.set = original_keymap_set
vim.api.nvim_win_close = failed_cleanup_win_close
vim.api.nvim_buf_delete = failed_cleanup_buf_delete
h.assert_true(not failed_cleanup_ok, 'raw dynamic open accepted failed cleanup after install failure', scope)
h.assert_true(
  failed_cleanup_instance.state.raw_dynamic ~= nil,
  'failed raw dynamic cleanup dropped live raw state',
  scope
)
h.assert_true(
  vim.api.nvim_win_is_valid(failed_cleanup_instance.state.raw_dynamic.win),
  'failed raw dynamic cleanup did not leave a live window',
  scope
)
h.assert_true(
  vim.api.nvim_buf_is_valid(failed_cleanup_instance.state.raw_dynamic.buf),
  'failed raw dynamic cleanup did not leave a live buffer',
  scope
)
h.assert_true(
  tostring(failed_cleanup_err):find('close failed', 1, true) ~= nil
    and tostring(failed_cleanup_err):find('delete failed', 1, true) ~= nil,
  'failed raw dynamic cleanup did not aggregate cleanup errors',
  scope
)
raw_dynamic.close(failed_cleanup_instance)

local preserved_raw_buf = vim.api.nvim_create_buf(false, true)
local preserved_raw_win = vim.api.nvim_open_win(preserved_raw_buf, false, {
  relative = 'editor',
  style = 'minimal',
  width = 1,
  height = 1,
  row = 0,
  col = 0,
})
instance.state.raw_dynamic = {
  buf = preserved_raw_buf,
  win = preserved_raw_win,
}
local inactive_raw_ok, inactive_raw_err = raw_dynamic.open(instance, result, 'bg')
h.assert_true(not inactive_raw_ok, 'raw dynamic open accepted inactive dynamic field', scope)
h.assert_equal(inactive_raw_err, 'No dynamic color field is active', 'inactive raw dynamic error changed', scope)
h.assert_true(vim.api.nvim_win_is_valid(preserved_raw_win), 'failed raw dynamic open closed existing window', scope)
h.assert_true(vim.api.nvim_buf_is_valid(preserved_raw_buf), 'failed raw dynamic open deleted existing buffer', scope)
h.assert_equal(instance.state.raw_dynamic.win, preserved_raw_win, 'failed raw dynamic open changed raw state', scope)
raw_dynamic.close(instance)

local close_failure_instance = { state = {} }
local close_open_ok, close_open_err = raw_dynamic.open(close_failure_instance, result, 'fg')
h.assert_true(close_open_ok, close_open_err or 'raw dynamic close failure editor did not open', scope)
local close_failure_buf = close_failure_instance.state.raw_dynamic.buf
local close_failure_win = close_failure_instance.state.raw_dynamic.win
local close_callback = keymap_callback(close_failure_buf, 'q')
h.assert_true(type(close_callback) == 'function', 'raw dynamic close mapping did not expose a callback', scope)
local original_win_close = vim.api.nvim_win_close
local original_buf_delete = vim.api.nvim_buf_delete
vim.api.nvim_win_close = function()
  error('close failed')
end
vim.api.nvim_buf_delete = function()
  error('delete failed')
end
local close_notifications = {}
local close_callback_ok = h.with_notify_stub(function()
  return pcall(close_callback)
end, function(message)
  close_notifications[#close_notifications + 1] = message
end)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
h.assert_true(close_callback_ok, 'raw dynamic close callback error escaped the keymap', scope)
h.assert_true(
  close_notifications[1]
    and close_notifications[1]:find('failed to close raw dynamic editor', 1, true) ~= nil
    and close_notifications[1]:find('close failed', 1, true) ~= nil
    and close_notifications[1]:find('delete failed', 1, true) ~= nil,
  'raw dynamic close callback failure was not notified',
  scope
)
h.assert_true(
  close_failure_instance.state.raw_dynamic ~= nil,
  'failed raw dynamic close callback dropped raw state',
  scope
)

vim.api.nvim_win_close = function()
  error('close failed')
end
vim.api.nvim_buf_delete = function()
  error('delete failed')
end
local failed_close_result, failed_close_err = raw_dynamic.close(close_failure_instance)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
h.assert_true(not failed_close_result, 'raw dynamic close reported success after failed cleanup', scope)
h.assert_true(
  tostring(failed_close_err):find('close failed', 1, true) ~= nil
    and tostring(failed_close_err):find('delete failed', 1, true) ~= nil,
  'raw dynamic close did not aggregate cleanup errors',
  scope
)
h.assert_true(close_failure_instance.state.raw_dynamic ~= nil, 'failed raw dynamic close dropped raw state', scope)
h.assert_true(vim.api.nvim_win_is_valid(close_failure_win), 'failed raw dynamic close invalidated test window', scope)
raw_dynamic.close(close_failure_instance)
h.assert_true(close_failure_instance.state.raw_dynamic == nil, 'raw dynamic close retry kept raw state', scope)

local reopen_failure_instance = { state = {} }
local reopen_existing_buf = vim.api.nvim_create_buf(false, true)
local reopen_existing_win = vim.api.nvim_open_win(reopen_existing_buf, false, {
  relative = 'editor',
  style = 'minimal',
  width = 1,
  height = 1,
  row = 0,
  col = 0,
})
reopen_failure_instance.state.raw_dynamic = {
  buf = reopen_existing_buf,
  win = reopen_existing_win,
}
original_win_close = vim.api.nvim_win_close
original_buf_delete = vim.api.nvim_buf_delete
vim.api.nvim_win_close = function(win, ...)
  if win == reopen_existing_win then
    error('close failed')
  end
  return original_win_close(win, ...)
end
vim.api.nvim_buf_delete = function(buf, ...)
  if buf == reopen_existing_buf then
    error('delete failed')
  end
  return original_buf_delete(buf, ...)
end
local reopen_failure_ok = pcall(raw_dynamic.open, reopen_failure_instance, result, 'fg')
local reopen_preserved_state = reopen_failure_instance.state.raw_dynamic
local reopen_preserved_existing = reopen_preserved_state ~= nil
  and reopen_preserved_state.win == reopen_existing_win
  and reopen_preserved_state.buf == reopen_existing_buf
local reopen_existing_still_valid = vim.api.nvim_win_is_valid(reopen_existing_win)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
if
  reopen_failure_instance.state.raw_dynamic and reopen_failure_instance.state.raw_dynamic.win ~= reopen_existing_win
then
  raw_dynamic.close(reopen_failure_instance)
end
if vim.api.nvim_win_is_valid(reopen_existing_win) then
  vim.api.nvim_win_close(reopen_existing_win, true)
end
h.assert_true(not reopen_failure_ok, 'raw dynamic open ignored failed previous close', scope)
h.assert_true(reopen_preserved_existing, 'failed raw dynamic reopen replaced existing state', scope)
h.assert_true(reopen_existing_still_valid, 'failed raw dynamic reopen invalidated existing window', scope)

local write_failure_instance = { state = {} }
local write_open_ok, write_open_err = raw_dynamic.open(write_failure_instance, result, 'fg')
h.assert_true(write_open_ok, write_open_err or 'raw dynamic write failure editor did not open', scope)
local write_buf = write_failure_instance.state.raw_dynamic.buf
local write_callback = keymap_callback(write_buf, 'w')
h.assert_true(type(write_callback) == 'function', 'raw dynamic write mapping did not expose a callback', scope)
local write_notifications = {}
local write_callback_ok = h.with_notify_stub(function()
  return pcall(write_callback)
end, function(message)
  write_notifications[#write_notifications + 1] = message
end)
h.assert_true(write_callback_ok, 'raw dynamic write callback error escaped the keymap', scope)
h.assert_true(
  write_notifications[1] and write_notifications[1]:find('session refresh requires a rerender callback', 1, true) ~= nil,
  'raw dynamic write callback error was not notified',
  scope
)
h.assert_true(vim.api.nvim_buf_is_valid(write_buf), 'failed raw dynamic write closed the editor buffer', scope)
raw_dynamic.close(write_failure_instance)

local write_close_failure_instance = {
  state = {},
  rerender = function() end,
}
local write_close_open_ok, write_close_open_err = raw_dynamic.open(write_close_failure_instance, result, 'fg')
h.assert_true(write_close_open_ok, write_close_open_err or 'raw dynamic write close failure editor did not open', scope)
local write_close_buf = write_close_failure_instance.state.raw_dynamic.buf
local write_close_callback = keymap_callback(write_close_buf, 'w')
h.assert_true(
  type(write_close_callback) == 'function',
  'raw dynamic write close mapping did not expose a callback',
  scope
)
original_win_close = vim.api.nvim_win_close
original_buf_delete = vim.api.nvim_buf_delete
vim.api.nvim_win_close = function()
  error('close failed')
end
vim.api.nvim_buf_delete = function()
  error('delete failed')
end
local write_close_notifications = {}
local write_close_callback_ok = h.with_notify_stub(function()
  return pcall(write_close_callback)
end, function(message)
  write_close_notifications[#write_close_notifications + 1] = message
end)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
h.assert_true(write_close_callback_ok, 'raw dynamic write close callback error escaped the keymap', scope)
h.assert_true(
  write_close_notifications[1]
    and write_close_notifications[1]:find('failed to close raw dynamic editor', 1, true) ~= nil,
  'raw dynamic write close failure was not notified',
  scope
)
raw_dynamic.close(write_close_failure_instance)

local original_columns = vim.o.columns
local original_lines = vim.o.lines
local tiny_raw_instance = {
  state = {},
}
local tiny_raw_ok, tiny_raw_err = xpcall(function()
  vim.o.columns = 30
  vim.o.lines = 10
  local open_ok, open_err = raw_dynamic.open(tiny_raw_instance, result, 'fg')
  h.assert_true(open_ok, open_err or 'tiny raw dynamic editor did not open', scope)
  local raw_state = tiny_raw_instance.state.raw_dynamic
  h.assert_true(
    vim.api.nvim_win_get_width(raw_state.win) <= vim.o.columns - 2,
    'tiny raw dynamic editor exceeded available width',
    scope
  )
  h.assert_true(
    vim.api.nvim_win_get_height(raw_state.win) <= math.max(1, vim.o.lines - 4),
    'tiny raw dynamic editor exceeded available height',
    scope
  )
end, debug.traceback)
raw_dynamic.close(tiny_raw_instance)
vim.o.columns = original_columns
vim.o.lines = original_lines
if not tiny_raw_ok then
  error(tiny_raw_err, 0)
end

engine.clear(name)
dynamic_runtime.reset()
h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui raw dynamic: OK')
