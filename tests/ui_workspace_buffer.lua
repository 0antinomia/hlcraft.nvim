local h = require('tests.helpers')
local scope = 'hlcraft ui workspace buffer'

local workspace_buffer = require('hlcraft.ui.workspace.buffer')
local ui_state = require('hlcraft.ui.state')
local window = require('hlcraft.ui.workspace.window')

local function assert_fails(fn, message)
  h.assert_true(not pcall(fn), message, scope)
end

local function new_instance(name)
  return {
    group_name = name,
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
  local buf = workspace_buffer.ensure(instance)
  h.assert_true(window.is_valid_buf(buf), 'workspace buffer was not created', scope)
  h.assert_equal(instance.state.buf, buf, 'workspace buffer handle was not stored', scope)
  h.assert_equal(vim.api.nvim_buf_get_name(buf):match('HLCRAFT$'), 'HLCRAFT', 'workspace buffer name changed', scope)
  h.assert_equal(vim.bo[buf].buftype, 'nofile', 'workspace buffer buftype changed', scope)
  h.assert_equal(vim.bo[buf].filetype, 'hlcraft', 'workspace buffer filetype changed', scope)
  h.assert_true(instance.group ~= nil, 'workspace autocmd group was not created', scope)
  h.assert_equal(workspace_buffer.ensure(instance), buf, 'workspace buffer did not reuse created buffer', scope)
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
