local h = require('tests.helpers')
local scope = 'hlcraft ui field editor actions'

local actions = require('hlcraft.ui.scene.field_editor_actions')
local config = require('hlcraft.config')
local engine = require('hlcraft.engine.service')
local field_scene = require('hlcraft.ui.scene.field_editor')
local hlcraft = require('hlcraft')

local persist_dir = h.temp_dir('hlcraft-ui-field-editor-actions')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, 'HlcraftUiFieldEditorActionsNormal', { fg = '#101010' })
engine.set_group('HlcraftUiFieldEditorActionsNormal', 'ui-field-editor-actions')

local result = { name = 'HlcraftUiFieldEditorActionsNormal' }
local instance = {
  state = {
    detail_index = 1,
    field_editor = { field = 'fg' },
    results = {
      result,
    },
  },
  rerender = function() end,
}

local scene_ok, scene_err = field_scene.handle(instance, 'set_color', '#abcdef')
h.assert_true(scene_ok, scene_err or 'field scene set_color failed', scope)
h.assert_equal(engine.get(result.name).fg, '#abcdef', 'field scene did not delegate set_color', scope)

local matched_color, color_ok, color_err = actions.handle(instance, 'set_color', result, 'fg', '#fedcba')
h.assert_true(matched_color, 'set_color action was not matched', scope)
h.assert_true(color_ok, color_err or 'set_color failed', scope)
h.assert_equal(engine.get(result.name).fg, '#fedcba', 'set_color did not update draft', scope)
h.assert_equal(instance.state.field_editor.field, 'fg', 'set_color did not preserve field', scope)

local matched_dynamic, dynamic_ok, dynamic_err = actions.handle(instance, 'toggle_dynamic', result, 'fg')
h.assert_true(matched_dynamic, 'toggle_dynamic action was not matched', scope)
h.assert_true(dynamic_ok, dynamic_err or 'toggle_dynamic failed', scope)
h.assert_true(engine.get(result.name).dynamic.fg ~= nil, 'toggle_dynamic did not set dynamic config', scope)

local matched_static, static_ok = actions.handle(instance, 'set_color', result, 'fg', '#123456')
h.assert_true(matched_static, 'dynamic set_color action was not matched', scope)
h.assert_true(not static_ok, 'dynamic field accepted static color edit', scope)

local matched_phase, phase_ok, phase_err = actions.handle(instance, 'set_dynamic_phase', result, 'fg', 0.5)
h.assert_true(matched_phase, 'set_dynamic_phase action was not matched', scope)
h.assert_true(phase_ok, phase_err or 'set_dynamic_phase failed', scope)
h.assert_equal(engine.get(result.name).dynamic.fg.phase, 0.5, 'set_dynamic_phase did not update draft', scope)

local matched_blend, blend_ok, blend_err = actions.handle(instance, 'set_blend', result, 'blend', 12)
h.assert_true(matched_blend, 'set_blend action was not matched', scope)
h.assert_true(blend_ok, blend_err or 'set_blend failed', scope)
h.assert_equal(engine.get(result.name).blend, 12, 'set_blend did not update draft', scope)

local matched_blend_nan, blend_nan_ok, blend_nan_err = actions.handle(instance, 'adjust_blend', result, 'blend', 0 / 0)
h.assert_true(matched_blend_nan, 'adjust_blend action was not matched', scope)
h.assert_true(blend_nan_ok, blend_nan_err or 'adjust_blend with NaN failed', scope)
h.assert_equal(engine.get(result.name).blend, 12, 'adjust_blend with NaN changed draft', scope)

local matched_group, group_ok, group_err = actions.handle(instance, 'set_group', result, 'group', 'next-group')
h.assert_true(matched_group, 'set_group action was not matched', scope)
h.assert_true(group_ok, group_err or 'set_group failed', scope)
h.assert_equal(engine.get_draft_group(result.name), 'next-group', 'set_group did not update draft group', scope)

local matched_unknown = actions.handle(instance, 'unknown_action', result, 'fg')
h.assert_true(not matched_unknown, 'unknown action was matched', scope)

vim.fn.delete(persist_dir, 'rf')
config.setup({})

print('hlcraft ui field editor actions: OK')
