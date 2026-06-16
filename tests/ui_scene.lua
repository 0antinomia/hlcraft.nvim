local h = require('tests.helpers')

vim.cmd('runtime plugin/hlcraft.lua')

local hlcraft = require('hlcraft')
local engine = require('hlcraft.engine.service')
local Instance = require('hlcraft.ui.instance')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local results_state = require('hlcraft.ui.state.results')
local scene = require('hlcraft.ui.scene')
local actions = require('hlcraft.ui.actions')

local scope = 'hlcraft ui scene'

local persist_dir = h.temp_dir('hlcraft-ui-scene')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

local instance = Instance.new('ui-scene-test')
instance.state.scene.name = 'detail'
instance.state.detail_index = 1
instance.state.results = {
  { name = 'Normal' },
}
instance.rerender = function(self)
  self.did_rerender = true
end

results_state.force_close_detail(instance)

h.assert_equal(scene.current_name(instance), 'search', 'closing detail did not restore search scene', scope)

local cleanup_instance = Instance.new('ui-scene-cleanup-test')
cleanup_instance.state.scene.name = 'detail'
cleanup_instance.state.detail_index = 1

lifecycle.cleanup(cleanup_instance)

h.assert_equal(scene.current_name(cleanup_instance), 'search', 'cleanup did not restore search scene', scope)

local search_action_instance = Instance.new('ui-scene-search-action-test')
search_action_instance.state.buf = vim.api.nvim_get_current_buf()
search_action_instance.state.last_workspace_win = vim.api.nvim_get_current_win()
search_action_instance.state.scene.name = 'search'
search_action_instance.state.results = {
  { name = 'Normal' },
}
search_action_instance.state.geometry.result_lines = {
  [1] = 1,
}
search_action_instance.rerender = function(self)
  self.did_rerender = true
end
vim.api.nvim_buf_set_lines(search_action_instance.state.buf, 0, -1, false, { 'Normal' })
vim.api.nvim_win_set_cursor(search_action_instance.state.last_workspace_win, { 1, 0 })

local activate_ok, activate_err = actions.dispatch(search_action_instance, 'activate')
h.assert_true(activate_ok, activate_err or 'search activate action failed', scope)
h.assert_equal(
  search_action_instance.state.detail_index,
  1,
  'search activate action did not open detail for the result row',
  scope
)
h.assert_equal(
  scene.current_name(search_action_instance),
  'detail',
  'search activate action did not switch to detail scene',
  scope
)

local notify_calls = {}
local original_notify = vim.notify
vim.notify = function(message, level)
  notify_calls[#notify_calls + 1] = { message = message, level = level }
end

local unsupported_ok, unsupported_err = actions.dispatch(search_action_instance, 'missing_action')
h.assert_equal(unsupported_ok, false, 'unsupported action did not return false', scope)
h.assert_true(unsupported_err ~= nil, 'unsupported action did not return an error', scope)
h.assert_equal(#notify_calls, 1, 'unsupported action did not notify through dispatcher', scope)
h.assert_equal(
  notify_calls[1].level,
  vim.log.levels.ERROR,
  'unsupported action notification level was not ERROR',
  scope
)

local back_instance = Instance.new('ui-scene-action-back-test')
back_instance.state.scene.name = 'detail'
back_instance.state.detail_index = 1
back_instance.state.results = {
  { name = 'Normal' },
}
back_instance.rerender = function(self)
  self.did_rerender = true
end

local back_ok, back_err = actions.back(back_instance)
vim.notify = original_notify
h.assert_true(back_ok, back_err or 'actions.back failed', scope)
h.assert_equal(scene.current_name(back_instance), 'search', 'actions.back did not delegate to scene back', scope)

local editor_cleanup_instance = Instance.new('ui-scene-editor-cleanup-test')
editor_cleanup_instance.state.scene.name = 'field_editor'
editor_cleanup_instance.state.detail_index = 1
editor_cleanup_instance.state.field_editor.field = 'fg'
editor_cleanup_instance.state.field_editor.palette_index = 2

lifecycle.cleanup(editor_cleanup_instance)

h.assert_equal(
  scene.current_name(editor_cleanup_instance),
  'search',
  'cleanup did not restore search scene from editor',
  scope
)
h.assert_equal(
  editor_cleanup_instance.state.field_editor.field,
  nil,
  'cleanup did not clear active editor field',
  scope
)
h.assert_equal(
  editor_cleanup_instance.state.field_editor.palette_index,
  nil,
  'cleanup did not clear editor palette index',
  scope
)

local missing_group_result_instance = Instance.new('ui-scene-missing-group-result-test')
missing_group_result_instance.state.buf = vim.api.nvim_get_current_buf()
missing_group_result_instance.state.last_workspace_win = vim.api.nvim_get_current_win()
missing_group_result_instance.state.scene.name = 'field_editor'
missing_group_result_instance.state.detail_index = 1
missing_group_result_instance.state.field_editor.field = 'group'
missing_group_result_instance.state.results = {}
missing_group_result_instance.state.geometry.editor_rows = {
  [1] = { line = 1, key = 'group:Comment' },
}
vim.api.nvim_buf_set_lines(missing_group_result_instance.state.buf, 0, -1, false, { 'Comment' })
vim.api.nvim_win_set_cursor(missing_group_result_instance.state.last_workspace_win, { 1, 0 })

local no_result_threw, no_result_ok = pcall(scene.handle, missing_group_result_instance, 'activate')
h.assert_true(no_result_threw, 'field editor group activation threw without a current result', scope)
h.assert_equal(
  no_result_ok,
  false,
  'field editor group activation without a current result did not fail normally',
  scope
)

vim.api.nvim_set_hl(0, 'HlcraftUiSceneNormal', { fg = '#010203' })

local field_editor_instance = Instance.new('ui-scene-field-editor-test')
field_editor_instance.state.scene.name = 'field_editor'
field_editor_instance.state.detail_index = 1
field_editor_instance.state.field_editor.field = 'fg'
field_editor_instance.state.results = {
  { name = 'HlcraftUiSceneNormal', fg = '#010203', resolved_fg = '#010203' },
}
field_editor_instance.rerender = function(self)
  self.did_rerender = true
end

local color_ok, color_err = scene.handle(field_editor_instance, 'set_color', '#abcdef')
h.assert_true(color_ok, color_err or 'scene set_color failed', scope)
h.assert_equal(engine.get('HlcraftUiSceneNormal').fg, '#abcdef', 'scene set_color did not update draft fg', scope)
h.assert_equal(
  field_editor_instance.state.field_editor.field,
  'fg',
  'scene set_color did not preserve active editor field',
  scope
)
h.assert_true(field_editor_instance.did_rerender == true, 'scene set_color did not refresh the instance', scope)

vim.fn.delete(persist_dir, 'rf')
print('hlcraft ui scene: OK')
