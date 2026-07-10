local h = require('tests.helpers')
local scope = 'hlcraft ui workspace buffer'

local workspace_buffer = require('hlcraft.ui.workspace.buffer')
local ui_state = require('hlcraft.ui.state')
local window = require('hlcraft.ui.workspace.window')

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

assert_fails(function()
  workspace_buffer.ensure(nil)
end, 'workspace buffer accepted missing instance')
assert_fails(function()
  workspace_buffer.ensure({ state = false })
end, 'workspace buffer accepted invalid state')
assert_fails(function()
  workspace_buffer.ensure({
    state = ui_state.initial(),
    rerender = function() end,
    cleanup = function() end,
  })
end, 'workspace buffer accepted missing group name')

h.with_temp_buf(function(existing)
  local existing_instance = {
    state = {
      buf = existing,
    },
  }
  h.assert_equal(
    workspace_buffer.ensure(existing_instance),
    existing,
    'workspace buffer did not reuse valid buffer',
    scope
  )
end)

local instance = new_instance('HlcraftUiWorkspaceBufferTest')
local ok, err = xpcall(function()
  local failing_instance = new_instance('HlcraftUiWorkspaceBufferFailure')
  local buffers_before_failure = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    buffers_before_failure[buf] = true
  end
  local original_keymap_set = vim.keymap.set
  vim.keymap.set = function()
    error('workspace keymap failed')
  end
  local failing_ok = pcall(workspace_buffer.ensure, failing_instance)
  vim.keymap.set = original_keymap_set
  h.assert_true(not failing_ok, 'workspace buffer accepted failed keymap setup', scope)
  h.assert_true(failing_instance.state.buf == nil, 'failed workspace buffer setup kept buffer state', scope)
  h.assert_true(failing_instance.group == nil, 'failed workspace buffer setup kept autocmd group', scope)
  for _, listed_buf in ipairs(vim.api.nvim_list_bufs()) do
    h.assert_true(
      buffers_before_failure[listed_buf] or not vim.api.nvim_buf_is_valid(listed_buf),
      'failed workspace buffer setup leaked a buffer',
      scope
    )
  end

  local delete_failure_instance = new_instance('HlcraftUiWorkspaceBufferDeleteFailure')
  local delete_failure_buf
  local original_buf_delete = vim.api.nvim_buf_delete
  vim.keymap.set = function()
    error('workspace keymap failed')
  end
  vim.api.nvim_buf_delete = function(buf, ...)
    delete_failure_buf = buf
    error('workspace buffer delete failed')
  end
  local delete_failure_ok, delete_failure_err = pcall(workspace_buffer.ensure, delete_failure_instance)
  vim.keymap.set = original_keymap_set
  vim.api.nvim_buf_delete = original_buf_delete
  local delete_failure_kept_buf = delete_failure_instance.state.buf
  local delete_failure_buf_valid = delete_failure_buf ~= nil and vim.api.nvim_buf_is_valid(delete_failure_buf)
  if delete_failure_buf_valid then
    vim.api.nvim_buf_delete(delete_failure_buf, { force = true })
  end
  h.assert_true(not delete_failure_ok, 'workspace buffer accepted failed rollback delete', scope)
  h.assert_true(delete_failure_buf_valid, 'workspace buffer rollback delete failure lost its fixture', scope)
  h.assert_equal(
    delete_failure_kept_buf,
    delete_failure_buf,
    'workspace buffer rollback delete failure dropped the live buffer handle',
    scope
  )
  h.assert_true(
    tostring(delete_failure_err):find('workspace buffer delete failed', 1, true) ~= nil,
    'workspace buffer rollback delete failure omitted the cleanup error',
    scope
  )

  local stale_group_instance = new_instance('HlcraftUiWorkspaceBufferStaleGroup')
  local stale_group_buf = vim.api.nvim_create_buf(false, true)
  stale_group_instance.group = vim.api.nvim_create_augroup(stale_group_instance.group_name, { clear = true })
  stale_group_instance.autocmd_buf = stale_group_buf
  local stale_group_id = stale_group_instance.group
  local original_create_autocmd = vim.api.nvim_create_autocmd
  vim.api.nvim_create_autocmd = function()
    error('workspace autocmd failed')
  end
  local stale_group_ok = pcall(workspace_buffer.ensure, stale_group_instance)
  vim.api.nvim_create_autocmd = original_create_autocmd
  local stale_group_exists = pcall(vim.api.nvim_get_autocmds, { group = stale_group_id })
  if stale_group_exists then
    vim.api.nvim_del_augroup_by_id(stale_group_id)
  end
  vim.api.nvim_buf_delete(stale_group_buf, { force = true })
  h.assert_true(not stale_group_ok, 'workspace buffer accepted failed autocmd rebuild', scope)
  h.assert_true(not stale_group_exists, 'workspace autocmd rebuild failure kept a deleted fixture group', scope)
  h.assert_true(stale_group_instance.group == nil, 'workspace buffer restored a deleted autocmd group handle', scope)
  h.assert_true(
    stale_group_instance.autocmd_buf == nil,
    'workspace buffer restored a deleted autocmd buffer binding',
    scope
  )

  local buf = workspace_buffer.ensure(instance)
  h.assert_true(window.is_valid_buf(buf), 'workspace buffer was not created', scope)
  h.assert_equal(instance.state.buf, buf, 'workspace buffer handle was not stored', scope)
  h.assert_equal(vim.api.nvim_buf_get_name(buf), 'HLCRAFT://' .. instance.id, 'workspace buffer name changed', scope)
  h.assert_equal(vim.bo[buf].buftype, 'nofile', 'workspace buffer buftype changed', scope)
  h.assert_equal(vim.bo[buf].filetype, 'hlcraft', 'workspace buffer filetype changed', scope)
  h.assert_true(instance.group ~= nil, 'workspace autocmd group was not created', scope)
  h.assert_equal(workspace_buffer.ensure(instance), buf, 'workspace buffer did not reuse created buffer', scope)

  local second_instance = new_instance('HlcraftUiWorkspaceBufferSecond')
  local second_buf = workspace_buffer.ensure(second_instance)
  h.assert_true(window.is_valid_buf(second_buf), 'second workspace buffer was not created', scope)
  h.assert_true(
    vim.api.nvim_buf_get_name(second_buf) ~= vim.api.nvim_buf_get_name(buf),
    'named workspace instances reused the same buffer name',
    scope
  )
  pcall(vim.api.nvim_del_augroup_by_id, second_instance.group)
  pcall(vim.api.nvim_buf_delete, second_buf, { force = true })
end, debug.traceback)

if instance.group ~= nil then
  pcall(vim.api.nvim_del_augroup_by_id, instance.group)
end
if window.is_valid_buf(instance.state.buf) then
  pcall(vim.api.nvim_buf_delete, instance.state.buf, { force = true })
end

if not ok then
  error(err, 0)
end

print('hlcraft ui workspace buffer: OK')
