local h = require('tests.helpers')

local Instance = require('hlcraft.ui.instance')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local results_state = require('hlcraft.ui.state.results')
local scene = require('hlcraft.ui.scene')

local scope = 'hlcraft ui scene'

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
print('hlcraft ui scene: OK')
