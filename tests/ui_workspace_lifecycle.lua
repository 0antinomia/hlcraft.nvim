local h = require('tests.helpers')
local scope = 'hlcraft ui workspace lifecycle'

local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local ui_state = require('hlcraft.ui.state')

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
assert_fails(function()
  lifecycle.toggle_help({
    state = ui_state.initial(),
  })
end, 'workspace lifecycle help accepted invalid namespace')

local instance = new_instance('HlcraftUiWorkspaceLifecycleTest')
instance.state.closing = true
lifecycle.hide(instance)
h.assert_true(instance.state.closing, 'workspace lifecycle hide ignored closing guard incorrectly', scope)

instance.state.closing = false
lifecycle.hide(instance)
h.assert_true(not instance.state.closing, 'workspace lifecycle hide kept closing guard', scope)

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

print('hlcraft ui workspace lifecycle: OK')
