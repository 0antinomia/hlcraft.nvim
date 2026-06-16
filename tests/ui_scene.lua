local h = require('tests.helpers')

vim.cmd('runtime plugin/hlcraft.lua')

local hlcraft = require('hlcraft')
local engine = require('hlcraft.engine.service')
local Instance = require('hlcraft.ui.instance')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local results_state = require('hlcraft.ui.state.results')
local scene = require('hlcraft.ui.scene')

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
