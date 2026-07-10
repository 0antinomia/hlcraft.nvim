local h = require('tests.helpers')
local scope = 'hlcraft ui workspace lifecycle'

local config = require('hlcraft.config')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local ui_state = require('hlcraft.ui.state')
local window_options = require('hlcraft.ui.window_options')
local workspace_window = require('hlcraft.ui.workspace.window')

local assert_fails = h.scoped_assert_fails(scope)

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

local function failed_open_state(instance)
  local original_win = vim.api.nvim_get_current_win()
  local original_buf = vim.api.nvim_get_current_buf()
  local original_options = window_options.snapshot(original_win)
  local ok = pcall(lifecycle.open, instance)
  local state = {
    ok = ok,
    buf = instance.state.buf,
    group = instance.group,
    changed_current_buf = vim.api.nvim_get_current_buf() ~= original_buf,
    name_query = instance.state.name_query,
    results = vim.deepcopy(instance.state.results),
    window_options = window_options.read(original_win),
    original_options = original_options.values,
  }

  if vim.api.nvim_buf_is_valid(original_buf) then
    vim.api.nvim_set_current_buf(original_buf)
  end
  if state.group ~= nil then
    pcall(vim.api.nvim_del_augroup_by_id, state.group)
  end
  if state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  window_options.restore(original_options)

  return state
end

assert_fails(function()
  lifecycle.hide(nil)
end, 'workspace lifecycle hide accepted missing instance')
assert_fails(function()
  lifecycle.close({ state = false })
end, 'workspace lifecycle close accepted invalid state')
assert_fails(function()
  lifecycle.cleanup(nil)
end, 'workspace lifecycle cleanup accepted missing instance')
assert_fails(function()
  lifecycle.open({
    group_name = 'HlcraftUiWorkspaceLifecycleMissingRerender',
    state = ui_state.initial(),
    cleanup = function() end,
  })
end, 'workspace lifecycle open accepted missing rerender callback')

local invalid_ns_instance = new_instance('HlcraftUiWorkspaceLifecycleInvalidNs')
invalid_ns_instance.ns = false
local invalid_ns_open = failed_open_state(invalid_ns_instance)
h.assert_true(not invalid_ns_open.ok, 'workspace lifecycle open accepted invalid namespace', scope)
h.assert_true(invalid_ns_open.buf == nil, 'failed workspace open kept buffer handle', scope)
h.assert_true(invalid_ns_open.group == nil, 'failed workspace open kept autocmd group', scope)
h.assert_true(not invalid_ns_open.changed_current_buf, 'failed workspace open changed current buffer', scope)

local render_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleRenderFailure')
render_failure_instance.state.name_query = 'before'
render_failure_instance.state.results = {
  { name = 'Before' },
}
render_failure_instance.rerender = function(self)
  self.state.name_query = 'after'
  self.state.results = {
    { name = 'After' },
  }
  error('render failed')
end
local render_failure_open = failed_open_state(render_failure_instance)
h.assert_true(not render_failure_open.ok, 'workspace lifecycle open accepted failed render', scope)
h.assert_true(render_failure_open.buf == nil, 'render-failed workspace open kept buffer handle', scope)
h.assert_true(render_failure_open.group == nil, 'render-failed workspace open kept autocmd group', scope)
h.assert_true(not render_failure_open.changed_current_buf, 'render-failed workspace open changed current buffer', scope)
h.assert_true(
  vim.deep_equal(render_failure_open.window_options, render_failure_open.original_options),
  'render-failed workspace open kept workspace window options',
  scope
)
h.assert_equal(render_failure_open.name_query, 'before', 'render-failed workspace open changed query state', scope)
h.assert_true(
  vim.deep_equal(render_failure_open.results, {
    { name = 'Before' },
  }),
  'render-failed workspace open changed result state',
  scope
)

local rollback_delete_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleRollbackDeleteFailure')
local rollback_delete_buf
rollback_delete_failure_instance.rerender = function(self)
  rollback_delete_buf = self.state.buf
  error('render failed')
end
local original_rollback_buf_delete = vim.api.nvim_buf_delete
vim.api.nvim_buf_delete = function(buf, ...)
  if rollback_delete_buf ~= nil and buf == rollback_delete_buf then
    error('workspace delete failed')
  end
  return original_rollback_buf_delete(buf, ...)
end
local rollback_delete_open_ok, rollback_delete_open_err = pcall(lifecycle.open, rollback_delete_failure_instance)
vim.api.nvim_buf_delete = original_rollback_buf_delete
local rollback_delete_kept_buf = rollback_delete_failure_instance.state.buf
local rollback_delete_buf_valid = rollback_delete_buf ~= nil and vim.api.nvim_buf_is_valid(rollback_delete_buf)
if rollback_delete_buf_valid then
  vim.api.nvim_buf_delete(rollback_delete_buf, { force = true })
end
h.assert_true(not rollback_delete_open_ok, 'workspace open accepted failed render after failed rollback delete', scope)
h.assert_true(rollback_delete_buf_valid, 'rollback delete failure test did not preserve a valid buffer', scope)
h.assert_equal(
  rollback_delete_kept_buf,
  rollback_delete_buf,
  'delete-failed workspace open dropped the leaked workspace buffer handle',
  scope
)
h.assert_true(
  tostring(rollback_delete_open_err):find('workspace delete failed', 1, true) ~= nil,
  'delete-failed workspace open did not report the buffer cleanup error',
  scope
)

local rollback_group_delete_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleRollbackGroupDeleteFailure')
local rollback_group_delete_buf
local rollback_group_delete_group
rollback_group_delete_failure_instance.rerender = function(self)
  rollback_group_delete_buf = self.state.buf
  rollback_group_delete_group = self.group
  error('render failed')
end
local original_rollback_group_delete = vim.api.nvim_del_augroup_by_id
vim.api.nvim_del_augroup_by_id = function(group, ...)
  if rollback_group_delete_group ~= nil and group == rollback_group_delete_group then
    error('workspace group delete failed')
  end
  return original_rollback_group_delete(group, ...)
end
local rollback_group_delete_open_ok = pcall(lifecycle.open, rollback_group_delete_failure_instance)
vim.api.nvim_del_augroup_by_id = original_rollback_group_delete
local rollback_group_delete_kept_group = rollback_group_delete_failure_instance.group
local rollback_group_delete_group_exists = rollback_group_delete_group ~= nil
  and pcall(vim.api.nvim_get_autocmds, { group = rollback_group_delete_group })
if rollback_group_delete_group_exists then
  vim.api.nvim_del_augroup_by_id(rollback_group_delete_group)
end
if rollback_group_delete_buf ~= nil and vim.api.nvim_buf_is_valid(rollback_group_delete_buf) then
  vim.api.nvim_buf_delete(rollback_group_delete_buf, { force = true })
end
h.assert_true(
  not rollback_group_delete_open_ok,
  'workspace open accepted failed render after failed group rollback',
  scope
)
h.assert_true(rollback_group_delete_group_exists, 'rollback group delete failure test did not preserve a group', scope)
h.assert_equal(
  rollback_group_delete_kept_group,
  rollback_group_delete_group,
  'group-delete-failed workspace open dropped the leaked autocmd group handle',
  scope
)

h.with_temp_buf(function(buf)
  local reopen_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleReopenFailure')
  reopen_failure_instance.state.buf = buf
  reopen_failure_instance.state.last_workspace_win = vim.api.nvim_get_current_win()
  reopen_failure_instance.state.dynamic_preview.items = {
    {
      id = 1,
      text = 'OLD',
    },
  }
  reopen_failure_instance.rerender = function(self)
    self.state.dynamic_preview.items = {}
    error('render failed')
  end
  local previous_dynamic_preview = vim.deepcopy(reopen_failure_instance.state.dynamic_preview)
  local reopen_failure_ok = pcall(lifecycle.open, reopen_failure_instance)
  h.assert_true(not reopen_failure_ok, 'workspace lifecycle accepted failed reopen render', scope)
  h.assert_true(
    vim.deep_equal(reopen_failure_instance.state.dynamic_preview, previous_dynamic_preview),
    'render-failed workspace reopen changed dynamic preview state',
    scope
  )
end, { current = true })

local preview_rollback_lhs = '<Plug>(HlcraftLifecyclePreviewRollback)'
pcall(vim.keymap.del, 'n', preview_rollback_lhs)
local original_config = config.config
config.setup({
  keymaps = {
    preview = {
      lhs = preview_rollback_lhs,
      mode = 'n',
      opts = {
        desc = 'hlcraft lifecycle preview rollback',
      },
    },
  },
})
h.with_temp_buf(function(buf)
  local keymap_failure_instance = new_instance('HlcraftUiWorkspaceLifecyclePreviewKeymapRollback')
  keymap_failure_instance.state.buf = buf
  keymap_failure_instance.state.last_workspace_win = vim.api.nvim_get_current_win()
  keymap_failure_instance.rerender = function(self)
    self.state.geometry = ui_state.geometry()
    self.state.geometry.inputs = {
      { name = 'name', kind = 'name', line = 1 },
    }
    self.state.extmark_ids = false
  end
  local preview_keymap_failure_ok = pcall(lifecycle.open, keymap_failure_instance)
  local leaked_preview_keymap = vim.fn.maparg(preview_rollback_lhs, 'n', false, true)
  pcall(vim.keymap.del, 'n', preview_rollback_lhs)
  h.assert_true(not preview_keymap_failure_ok, 'workspace lifecycle open accepted failed post-keymap setup', scope)
  h.assert_true(
    type(leaked_preview_keymap) ~= 'table' or vim.tbl_isempty(leaked_preview_keymap),
    'failed workspace reopen leaked preview keymap',
    scope
  )
end, { current = true })

h.with_temp_buf(function(buf)
  local keymap_cleanup_failure_instance = new_instance('HlcraftUiWorkspaceLifecyclePreviewKeymapCleanupFailure')
  keymap_cleanup_failure_instance.state.buf = buf
  keymap_cleanup_failure_instance.state.last_workspace_win = vim.api.nvim_get_current_win()
  keymap_cleanup_failure_instance.rerender = function(self)
    self.state.geometry = ui_state.geometry()
    self.state.geometry.inputs = {
      { name = 'name', kind = 'name', line = 1 },
    }
    self.state.extmark_ids = false
  end
  local original_keymap_del = vim.keymap.del
  vim.keymap.del = function(mode, lhs, ...)
    if mode == 'n' and lhs == preview_rollback_lhs then
      error('preview keymap delete failed')
    end
    return original_keymap_del(mode, lhs, ...)
  end
  local preview_keymap_cleanup_failure_ok = pcall(lifecycle.open, keymap_cleanup_failure_instance)
  vim.keymap.del = original_keymap_del
  local leaked_preview_keymap = vim.fn.maparg(preview_rollback_lhs, 'n', false, true)
  local tracked_preview_keymap = keymap_cleanup_failure_instance.state.preview.keymap
  pcall(vim.keymap.del, 'n', preview_rollback_lhs)
  h.assert_true(
    not preview_keymap_cleanup_failure_ok,
    'workspace lifecycle open accepted failed setup with failed preview cleanup',
    scope
  )
  h.assert_true(
    type(leaked_preview_keymap) == 'table' and not vim.tbl_isempty(leaked_preview_keymap),
    'failed preview cleanup test did not leave an active preview map',
    scope
  )
  h.assert_true(
    type(tracked_preview_keymap) == 'table' and tracked_preview_keymap.lhs == preview_rollback_lhs,
    'failed workspace rollback dropped leaked preview keymap state',
    scope
  )
end, { current = true })
pcall(vim.keymap.del, 'n', preview_rollback_lhs)
vim.keymap.set('n', preview_rollback_lhs, '<Nop>', {
  desc = 'existing hlcraft lifecycle preview rollback',
})
local existing_preview_keymap_instance = new_instance('HlcraftUiWorkspaceLifecycleExistingPreviewKeymap')
existing_preview_keymap_instance.state.preview.keymap = {
  lhs = preview_rollback_lhs,
  mode = 'n',
  previous = nil,
}
existing_preview_keymap_instance.rerender = function()
  error('render failed')
end
local existing_preview_keymap_ok = pcall(lifecycle.open, existing_preview_keymap_instance)
local preserved_existing_preview_keymap = vim.fn.maparg(preview_rollback_lhs, 'n', false, true)
pcall(vim.keymap.del, 'n', preview_rollback_lhs)
h.assert_true(
  not existing_preview_keymap_ok,
  'workspace lifecycle open accepted failed render with existing preview keymap',
  scope
)
h.assert_true(
  type(preserved_existing_preview_keymap) == 'table' and not vim.tbl_isempty(preserved_existing_preview_keymap),
  'failed workspace open removed an existing preview keymap',
  scope
)
h.assert_true(
  type(existing_preview_keymap_instance.state.preview.keymap) == 'table'
    and existing_preview_keymap_instance.state.preview.keymap.lhs == preview_rollback_lhs,
  'failed workspace open dropped existing preview keymap state',
  scope
)
config.config = original_config

assert_fails(function()
  lifecycle.toggle_help({
    state = ui_state.initial(),
  })
end, 'workspace lifecycle help accepted invalid namespace')

local help_toggle_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleHelpToggleFailure')
local help_toggle_buf = vim.api.nvim_create_buf(false, true)
local help_toggle_win = vim.api.nvim_open_win(help_toggle_buf, false, {
  relative = 'editor',
  style = 'minimal',
  width = 1,
  height = 1,
  row = 0,
  col = 0,
})
help_toggle_failure_instance.state.help_buf = help_toggle_buf
help_toggle_failure_instance.state.help_win = help_toggle_win
local original_help_toggle_win_close = vim.api.nvim_win_close
vim.api.nvim_win_close = function()
  error('help close failed')
end
local help_toggle_notifications = {}
local help_toggle_ok = h.with_notify_stub(function()
  return lifecycle.toggle_help(help_toggle_failure_instance)
end, function(message)
  help_toggle_notifications[#help_toggle_notifications + 1] = message
end)
vim.api.nvim_win_close = original_help_toggle_win_close
h.assert_true(not help_toggle_ok, 'workspace lifecycle help toggle swallowed failed close', scope)
h.assert_true(
  help_toggle_notifications[1] and help_toggle_notifications[1]:find('failed to close help window', 1, true) ~= nil,
  'workspace lifecycle help toggle close failure was not notified',
  scope
)
h.assert_equal(
  help_toggle_failure_instance.state.help_win,
  help_toggle_win,
  'failed help toggle dropped help window handle',
  scope
)
vim.api.nvim_win_close(help_toggle_win, true)

local instance = new_instance('HlcraftUiWorkspaceLifecycleTest')
instance.state.closing = true
lifecycle.hide(instance)
h.assert_true(instance.state.closing, 'workspace lifecycle hide ignored closing guard incorrectly', scope)

instance.state.closing = false
local raw_buf = vim.api.nvim_create_buf(false, true)
local raw_win = vim.api.nvim_open_win(raw_buf, false, {
  relative = 'editor',
  style = 'minimal',
  width = 1,
  height = 1,
  row = 0,
  col = 0,
})
instance.state.raw_dynamic = { buf = raw_buf, win = raw_win }
lifecycle.hide(instance)
h.assert_true(not instance.state.closing, 'workspace lifecycle hide kept closing guard', scope)
h.assert_true(not vim.api.nvim_win_is_valid(raw_win), 'workspace lifecycle hide kept raw dynamic window', scope)
h.assert_true(not vim.api.nvim_buf_is_valid(raw_buf), 'workspace lifecycle hide kept raw dynamic buffer', scope)
h.assert_true(instance.state.raw_dynamic == nil, 'workspace lifecycle hide kept raw dynamic state', scope)

local debounce_stopped = 0
local debounce_closed = 0
instance.state.debounce_timer = {
  stop = function()
    debounce_stopped = debounce_stopped + 1
  end,
  close = function()
    debounce_closed = debounce_closed + 1
  end,
}
lifecycle.hide(instance)
h.assert_true(instance.state.debounce_timer == nil, 'workspace lifecycle hide kept debounce timer', scope)
h.assert_equal(debounce_stopped, 1, 'workspace lifecycle hide did not stop debounce timer', scope)
h.assert_equal(debounce_closed, 1, 'workspace lifecycle hide did not close debounce timer', scope)

local origin_restore_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleOriginRestoreFailure')
local origin_restore_win = vim.api.nvim_get_current_win()
local origin_restore_buf = vim.api.nvim_get_current_buf()
local origin_restore_workspace_buf = vim.api.nvim_create_buf(false, true)
vim.cmd('vsplit')
local origin_restore_workspace_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(origin_restore_workspace_win, origin_restore_workspace_buf)
origin_restore_failure_instance.state.buf = origin_restore_workspace_buf
origin_restore_failure_instance.state.origin_win = origin_restore_win
origin_restore_failure_instance.state.origin_buf = origin_restore_buf
origin_restore_failure_instance.state.origin_win_options = window_options.snapshot(origin_restore_win)
origin_restore_failure_instance.state.last_workspace_win = origin_restore_workspace_win
workspace_window.capture_workspace_window(origin_restore_failure_instance, origin_restore_workspace_win)
local origin_restore_original_win_close = vim.api.nvim_win_close
vim.api.nvim_win_close = function(win, ...)
  if win == origin_restore_workspace_win then
    error('origin restore close failed')
  end
  return origin_restore_original_win_close(win, ...)
end
local origin_restore_notifications = {}
local origin_restore_hide_ok = h.with_notify_stub(function()
  return lifecycle.hide(origin_restore_failure_instance)
end, function(message)
  origin_restore_notifications[#origin_restore_notifications + 1] = message
end)
vim.api.nvim_win_close = origin_restore_original_win_close
h.assert_true(not origin_restore_hide_ok, 'workspace lifecycle hide ignored failed origin restore', scope)
h.assert_true(
  origin_restore_notifications[1] and origin_restore_notifications[1]:find('origin window', 1, true) ~= nil,
  'workspace lifecycle hide did not notify origin restore failure',
  scope
)
h.assert_true(
  vim.api.nvim_win_is_valid(origin_restore_workspace_win),
  'origin-restore-failed hide invalidated workspace window',
  scope
)
h.assert_true(not origin_restore_failure_instance.state.closing, 'origin-restore-failed hide kept closing guard', scope)
if vim.api.nvim_win_is_valid(origin_restore_workspace_win) then
  vim.api.nvim_win_close(origin_restore_workspace_win, true)
end
if vim.api.nvim_buf_is_valid(origin_restore_workspace_buf) then
  vim.api.nvim_buf_delete(origin_restore_workspace_buf, { force = true })
end
if vim.api.nvim_win_is_valid(origin_restore_win) then
  vim.api.nvim_set_current_win(origin_restore_win)
end

local hide_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleHideFailure')
local prompt_buf = vim.api.nvim_create_buf(false, true)
local prompt_win = vim.api.nvim_open_win(prompt_buf, false, {
  relative = 'editor',
  style = 'minimal',
  width = 1,
  height = 1,
  row = 0,
  col = 0,
})
local hide_raw_buf = vim.api.nvim_create_buf(false, true)
local hide_raw_win = vim.api.nvim_open_win(hide_raw_buf, false, {
  relative = 'editor',
  style = 'minimal',
  width = 1,
  height = 1,
  row = 0,
  col = 0,
})
local hide_debounce_stopped = 0
hide_failure_instance.state.unsaved_prompt = {
  buf = prompt_buf,
  win = prompt_win,
}
hide_failure_instance.state.raw_dynamic = {
  buf = hide_raw_buf,
  win = hide_raw_win,
}
hide_failure_instance.state.debounce_timer = {
  stop = function()
    hide_debounce_stopped = hide_debounce_stopped + 1
  end,
  close = function() end,
}
local original_win_close = vim.api.nvim_win_close
local original_buf_delete = vim.api.nvim_buf_delete
vim.api.nvim_win_close = function(win, ...)
  if win == prompt_win then
    error('prompt close failed')
  end
  return original_win_close(win, ...)
end
vim.api.nvim_buf_delete = function(buf, ...)
  if buf == prompt_buf then
    error('prompt delete failed')
  end
  return original_buf_delete(buf, ...)
end
h.with_notify_stub(function()
  lifecycle.hide(hide_failure_instance)
end)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
h.assert_true(vim.api.nvim_win_is_valid(prompt_win), 'prompt-close-failed hide invalidated prompt window', scope)
h.assert_equal(
  hide_failure_instance.state.unsaved_prompt.win,
  prompt_win,
  'prompt-close-failed hide dropped prompt window handle',
  scope
)
h.assert_true(not vim.api.nvim_win_is_valid(hide_raw_win), 'prompt-close-failed hide kept raw dynamic window', scope)
h.assert_true(not vim.api.nvim_buf_is_valid(hide_raw_buf), 'prompt-close-failed hide kept raw dynamic buffer', scope)
h.assert_true(hide_failure_instance.state.raw_dynamic == nil, 'prompt-close-failed hide kept raw dynamic state', scope)
h.assert_equal(hide_debounce_stopped, 1, 'prompt-close-failed hide skipped debounce timer', scope)
h.assert_true(hide_failure_instance.state.debounce_timer == nil, 'prompt-close-failed hide kept debounce timer', scope)
vim.api.nvim_win_close(prompt_win, true)

local close_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleCloseFailure')
local close_workspace_buf = vim.api.nvim_create_buf(false, true)
local close_prompt_buf = vim.api.nvim_create_buf(false, true)
local close_prompt_win = vim.api.nvim_open_win(close_prompt_buf, false, {
  relative = 'editor',
  style = 'minimal',
  width = 1,
  height = 1,
  row = 0,
  col = 0,
})
close_failure_instance.state.buf = close_workspace_buf
close_failure_instance.state.unsaved_prompt = {
  buf = close_prompt_buf,
  win = close_prompt_win,
}
vim.api.nvim_win_close = function(win, ...)
  if win == close_prompt_win then
    error('prompt close failed')
  end
  return original_win_close(win, ...)
end
vim.api.nvim_buf_delete = function(buf, ...)
  if buf == close_prompt_buf then
    error('prompt delete failed')
  end
  return original_buf_delete(buf, ...)
end
h.with_notify_stub(function()
  lifecycle.close(close_failure_instance)
end)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
h.assert_true(
  vim.api.nvim_buf_is_valid(close_workspace_buf),
  'prompt-close-failed close deleted workspace buffer',
  scope
)
h.assert_equal(
  close_failure_instance.state.buf,
  close_workspace_buf,
  'prompt-close-failed close dropped workspace buffer handle',
  scope
)
vim.api.nvim_win_close(close_prompt_win, true)
vim.api.nvim_buf_delete(close_workspace_buf, { force = true })

local close_delete_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleCloseDeleteFailure')
local close_delete_failure_buf = vim.api.nvim_create_buf(false, true)
close_delete_failure_instance.state.buf = close_delete_failure_buf
original_buf_delete = vim.api.nvim_buf_delete
vim.api.nvim_buf_delete = function(buf, ...)
  if buf == close_delete_failure_buf then
    error('workspace delete failed')
  end
  return original_buf_delete(buf, ...)
end
local close_delete_notifications = {}
local close_delete_result = h.with_notify_stub(function()
  return lifecycle.close(close_delete_failure_instance)
end, function(message)
  close_delete_notifications[#close_delete_notifications + 1] = message
end)
vim.api.nvim_buf_delete = original_buf_delete
h.assert_equal(close_delete_result, false, 'workspace lifecycle close ignored failed buffer delete', scope)
h.assert_true(
  close_delete_notifications[1] and close_delete_notifications[1]:find('workspace buffer', 1, true) ~= nil,
  'workspace lifecycle close did not notify failed buffer delete',
  scope
)
h.assert_true(
  vim.api.nvim_buf_is_valid(close_delete_failure_buf),
  'delete-failed close invalidated workspace buffer',
  scope
)
h.assert_equal(
  close_delete_failure_instance.state.buf,
  close_delete_failure_buf,
  'delete-failed close dropped workspace buffer handle',
  scope
)
h.assert_true(not close_delete_failure_instance.state.closing, 'delete-failed close kept closing guard', scope)
vim.api.nvim_buf_delete(close_delete_failure_buf, { force = true })

local close_success_instance = new_instance('HlcraftUiWorkspaceLifecycleCloseSuccess')
local close_success_buf = vim.api.nvim_create_buf(false, true)
close_success_instance.state.buf = close_success_buf
lifecycle.close(close_success_instance)
h.assert_true(
  not vim.api.nvim_buf_is_valid(close_success_buf),
  'workspace lifecycle close kept workspace buffer alive',
  scope
)
h.assert_true(close_success_instance.state.buf == nil, 'workspace lifecycle close kept deleted buffer state', scope)

lifecycle.close(instance)
h.assert_true(not instance.state.closing, 'workspace lifecycle close kept closing guard', scope)

instance.state.results = { { name = 'Changed' } }
instance.state.name_query = 'changed'
instance.state.dynamic_preview.items = { { id = 1 } }
lifecycle.cleanup(instance)
h.assert_true(not instance.state.closing, 'workspace lifecycle cleanup kept closing guard', scope)
h.assert_true(next(instance.state.results) == nil, 'workspace lifecycle cleanup kept results', scope)
h.assert_equal(instance.state.name_query, '', 'workspace lifecycle cleanup kept query text', scope)
h.assert_true(
  next(instance.state.dynamic_preview.items) == nil,
  'workspace lifecycle cleanup kept dynamic items',
  scope
)

local help_failure_instance = new_instance('HlcraftUiWorkspaceLifecycleHelpFailure')
local help_failure_workspace_buf = vim.api.nvim_create_buf(false, true)
local help_buf = vim.api.nvim_create_buf(false, true)
local help_win = vim.api.nvim_open_win(help_buf, false, {
  relative = 'editor',
  style = 'minimal',
  width = 1,
  height = 1,
  row = 0,
  col = 0,
})
help_failure_instance.group = vim.api.nvim_create_augroup('HlcraftUiWorkspaceLifecycleHelpFailureGroup', {
  clear = true,
})
help_failure_instance.state.buf = help_failure_workspace_buf
help_failure_instance.state.help_buf = help_buf
help_failure_instance.state.help_win = help_win
original_win_close = vim.api.nvim_win_close
original_buf_delete = vim.api.nvim_buf_delete
vim.api.nvim_win_close = function(win, ...)
  if win == help_win then
    error('help close failed')
  end
  return original_win_close(win, ...)
end
vim.api.nvim_buf_delete = function(buf, ...)
  if buf == help_buf then
    error('help delete failed')
  end
  return original_buf_delete(buf, ...)
end
h.with_notify_stub(function()
  lifecycle.cleanup(help_failure_instance)
end)
vim.api.nvim_win_close = original_win_close
vim.api.nvim_buf_delete = original_buf_delete
h.assert_true(vim.api.nvim_win_is_valid(help_win), 'help-failed cleanup invalidated test window', scope)
h.assert_true(
  not vim.api.nvim_buf_is_valid(help_failure_workspace_buf),
  'help-failed cleanup kept workspace buffer alive',
  scope
)
h.assert_true(help_failure_instance.state.buf == nil, 'help-failed cleanup kept deleted workspace buffer state', scope)
h.assert_true(help_failure_instance.group == nil, 'help-failed cleanup kept deleted autocmd group state', scope)
h.assert_equal(help_failure_instance.state.help_win, help_win, 'help-failed cleanup dropped help window handle', scope)
h.assert_equal(help_failure_instance.state.help_buf, help_buf, 'help-failed cleanup dropped help buffer handle', scope)
vim.api.nvim_win_close(help_win, true)

print('hlcraft ui workspace lifecycle: OK')
