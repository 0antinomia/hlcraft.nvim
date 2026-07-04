local h = require('tests.helpers')
local scope = 'hlcraft ui context'

local config = require('hlcraft.config')
local context = require('hlcraft.ui.context')
local engine = require('hlcraft.engine.service')
local hlcraft = require('hlcraft')

local persist_dir = h.temp_dir('hlcraft-ui-context')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, 'HlcraftUiContextNormal', { fg = '#101010' })
engine.set_group('HlcraftUiContextNormal', 'ui-context')
local dynamic_ok, dynamic_err = engine.set_dynamic('HlcraftUiContextNormal', 'fg', {
  version = 1,
  preset = 'pulse',
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
  },
})
h.assert_true(dynamic_ok, dynamic_err or 'set dynamic failed', scope)

local instance = {
  state = {
    scene = { name = 'field_editor' },
    detail_index = 1,
    field_editor = { field = 'fg' },
    results = {
      { name = 'HlcraftUiContextNormal' },
    },
  },
}

h.assert_true(context.editor_scene_is_active(instance), 'field editor scene was not active', scope)
h.assert_equal(context.current_field(instance), 'fg', 'current field changed', scope)
h.assert_equal(context.current_field_kind(instance), 'color', 'field kind changed', scope)
h.assert_true(context.color_field_is_dynamic(instance), 'dynamic color field was not detected', scope)
h.assert_equal(context.current_color_dynamic(instance).preset, 'pulse', 'dynamic value changed', scope)

instance.state.field_editor.field = 'blend'
h.assert_equal(context.current_field_kind(instance), 'blend', 'blend field kind changed', scope)
h.assert_true(context.current_color_dynamic(instance) == nil, 'blend field returned color dynamic', scope)

instance.state.scene.name = 'search'
h.assert_true(not context.editor_scene_is_active(instance), 'search scene was treated as editor scene', scope)
h.assert_true(context.current_field_kind(instance) == nil, 'inactive editor returned field kind', scope)

vim.fn.delete(persist_dir, 'rf')
config.setup({})

print('hlcraft ui context: OK')
