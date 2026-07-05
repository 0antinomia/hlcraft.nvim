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

local matched_adjust_color, adjust_color_ok, adjust_color_err =
  actions.handle(instance, 'adjust_color', result, 'fg', 'r', 1)
h.assert_true(matched_adjust_color, 'adjust_color action was not matched', scope)
h.assert_true(adjust_color_ok, adjust_color_err or 'adjust_color failed', scope)
h.assert_equal(engine.get(result.name).fg, '#ffdcba', 'adjust_color did not update draft', scope)

local matched_bad_channel, bad_channel_ok, bad_channel_err =
  actions.handle(instance, 'adjust_color', result, 'fg', 1, 1)
h.assert_true(matched_bad_channel, 'bad channel adjust_color action was not matched', scope)
h.assert_true(not bad_channel_ok, 'adjust_color accepted a non-string channel', scope)
h.assert_equal(bad_channel_err, 'Color channel must be a string', 'bad channel error changed', scope)
h.assert_equal(engine.get(result.name).fg, '#ffdcba', 'bad channel changed color draft', scope)

local matched_bad_delta, bad_delta_ok, bad_delta_err =
  actions.handle(instance, 'adjust_color', result, 'fg', 'r', 0 / 0)
h.assert_true(matched_bad_delta, 'bad delta adjust_color action was not matched', scope)
h.assert_true(not bad_delta_ok, 'adjust_color accepted NaN delta', scope)
h.assert_equal(bad_delta_err, 'Color adjustment delta must be a finite number', 'bad delta error changed', scope)
h.assert_equal(engine.get(result.name).fg, '#ffdcba', 'bad delta changed color draft', scope)

local matched_raw_static, raw_static_ok, raw_static_err =
  actions.handle(instance, 'open_dynamic_raw_json', result, 'fg')
h.assert_true(matched_raw_static, 'open_dynamic_raw_json action was not matched', scope)
h.assert_true(not raw_static_ok, 'raw JSON editor opened for a static color field', scope)
h.assert_equal(raw_static_err, 'No dynamic color field is active', 'raw JSON static error changed', scope)
local invalid_action_instance_ok = pcall(actions.handle, nil, 'set_color', result, 'fg', '#ffffff')
h.assert_true(not invalid_action_instance_ok, 'field editor action accepted missing instance', scope)
local invalid_action_name_ok = pcall(actions.handle, instance, '', result, 'fg', '#ffffff')
h.assert_true(not invalid_action_name_ok, 'field editor action accepted empty action name', scope)
local invalid_action_result_ok = pcall(actions.handle, instance, 'set_color', {}, 'fg', '#ffffff')
h.assert_true(not invalid_action_result_ok, 'field editor action accepted nameless result', scope)
local invalid_action_field_ok = pcall(actions.handle, instance, 'set_color', result, false, '#ffffff')
h.assert_true(not invalid_action_field_ok, 'field editor action accepted invalid field', scope)
local missing_action_state_ok = pcall(actions.handle, { state = {} }, 'set_color', result, 'fg', '#ffffff')
h.assert_true(not missing_action_state_ok, 'field editor action accepted missing field editor state', scope)
h.assert_equal(engine.get(result.name).fg, '#ffdcba', 'missing field editor state changed color draft', scope)
local invalid_dynamic_input_opts_ok = pcall(field_scene.input_dynamic_row, instance, false)
h.assert_true(not invalid_dynamic_input_opts_ok, 'field editor accepted non-table dynamic input options', scope)
local unknown_dynamic_input_opts_ok = pcall(field_scene.input_dynamic_row, instance, { raw = true })
h.assert_true(not unknown_dynamic_input_opts_ok, 'field editor accepted unknown dynamic input options', scope)
local invalid_dynamic_input_default_ok = pcall(field_scene.input_dynamic_row, instance, { default_raw = 'yes' })
h.assert_true(not invalid_dynamic_input_default_ok, 'field editor accepted non-boolean dynamic raw fallback', scope)
local invalid_current_field_state_ok = pcall(field_scene.current_field, { state = {} })
h.assert_true(not invalid_current_field_state_ok, 'field editor accepted missing field state', scope)
local invalid_current_field_value_ok =
  pcall(field_scene.current_field, { state = { field_editor = { field = false } } })
h.assert_true(not invalid_current_field_value_ok, 'field editor accepted invalid current field', scope)
local invalid_scene_action_ok = pcall(field_scene.handle, instance, '')
h.assert_true(not invalid_scene_action_ok, 'field editor accepted empty scene action', scope)
local missing_scene_instance_ok = pcall(field_scene.handle, nil, 'activate')
h.assert_true(not missing_scene_instance_ok, 'field editor accepted missing scene instance', scope)

local rerenders = 0
local strict_instance = {
  state = {
    field_editor = { field = 'fg' },
    scene = { name = 'field_editor' },
    detail_index = 1,
  },
  rerender = function()
    rerenders = rerenders + 1
  end,
}
field_scene.open(strict_instance, 'bg')
h.assert_equal(strict_instance.state.field_editor.field, 'bg', 'field editor open did not set field', scope)
h.assert_equal(strict_instance.state.scene.field, 'bg', 'field editor open did not mirror scene field', scope)
field_scene.close(strict_instance)
h.assert_equal(strict_instance.state.field_editor.field, nil, 'field editor close did not clear field', scope)
h.assert_equal(strict_instance.state.scene.field, nil, 'field editor close did not clear scene field', scope)
h.assert_equal(rerenders, 2, 'field editor open/close did not rerender', scope)
local invalid_open_field_ok = pcall(field_scene.open, strict_instance, '')
h.assert_true(not invalid_open_field_ok, 'field editor open accepted empty field', scope)
local invalid_open_rerender_ok = pcall(field_scene.open, { state = { field_editor = {} } }, 'fg')
h.assert_true(not invalid_open_rerender_ok, 'field editor open accepted missing rerender callback', scope)
local invalid_back_index_ok =
  pcall(field_scene.back, { state = { field_editor = {}, detail_index = 0 }, rerender = function() end })
h.assert_true(not invalid_back_index_ok, 'field editor back accepted invalid detail index', scope)

instance.state.scene = { name = 'field_editor', kind = 'color' }
field_scene.enter(instance, { field = 'bg' })
h.assert_equal(instance.state.field_editor.field, 'bg', 'field editor enter did not set field', scope)
h.assert_equal(instance.state.scene.field, 'bg', 'field editor enter did not mirror scene field', scope)
h.assert_equal(instance.state.scene.kind, nil, 'field editor enter kept stale scene kind', scope)
local invalid_enter_opts_ok = pcall(field_scene.enter, instance, false)
h.assert_true(not invalid_enter_opts_ok, 'field editor enter accepted non-table options', scope)
local invalid_enter_field_ok = pcall(field_scene.enter, instance, { field = false })
h.assert_true(not invalid_enter_field_ok, 'field editor enter accepted non-string field', scope)
local unknown_enter_option_ok = pcall(field_scene.enter, instance, { kind = 'color' })
h.assert_true(not unknown_enter_option_ok, 'field editor enter accepted an unsupported option', scope)
local invalid_enter_scene_ok = pcall(field_scene.enter, { state = { field_editor = {} } }, {})
h.assert_true(not invalid_enter_scene_ok, 'field editor enter accepted missing scene state', scope)
instance.state.field_editor.field = 'fg'
instance.state.scene.field = 'fg'

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

local matched_blend_string, blend_string_ok, blend_string_err =
  actions.handle(instance, 'set_blend', result, 'blend', '15.9')
h.assert_true(matched_blend_string, 'set_blend string action was not matched', scope)
h.assert_true(blend_string_ok, blend_string_err or 'set_blend string failed', scope)
h.assert_equal(engine.get(result.name).blend, 15, 'set_blend string did not update draft', scope)

local matched_blend_bad_type, blend_bad_type_ok, blend_bad_type_err =
  actions.handle(instance, 'set_blend', result, 'blend', false)
h.assert_true(matched_blend_bad_type, 'set_blend bad type action was not matched', scope)
h.assert_true(not blend_bad_type_ok, 'set_blend accepted a non-string non-number value', scope)
h.assert_equal(
  blend_bad_type_err,
  'Blend must be a number between 0 and 100',
  'set_blend bad type error changed',
  scope
)
h.assert_equal(engine.get(result.name).blend, 15, 'set_blend bad type changed draft', scope)

local matched_blend_set_nan, blend_set_nan_ok = actions.handle(instance, 'set_blend', result, 'blend', 0 / 0)
h.assert_true(matched_blend_set_nan, 'set_blend NaN action was not matched', scope)
h.assert_true(not blend_set_nan_ok, 'set_blend accepted NaN', scope)
h.assert_equal(engine.get(result.name).blend, 15, 'set_blend NaN changed draft', scope)

local matched_blend_nan, blend_nan_ok, blend_nan_err = actions.handle(instance, 'adjust_blend', result, 'blend', 0 / 0)
h.assert_true(matched_blend_nan, 'adjust_blend action was not matched', scope)
h.assert_true(not blend_nan_ok, 'adjust_blend accepted NaN delta', scope)
h.assert_equal(blend_nan_err, 'Blend adjustment delta must be a finite number', 'adjust_blend NaN error changed', scope)
h.assert_equal(engine.get(result.name).blend, 15, 'adjust_blend with NaN changed draft', scope)

local matched_group, group_ok, group_err = actions.handle(instance, 'set_group', result, 'group', 'next-group')
h.assert_true(matched_group, 'set_group action was not matched', scope)
h.assert_true(group_ok, group_err or 'set_group failed', scope)
h.assert_equal(engine.get_draft_group(result.name), 'next-group', 'set_group did not update draft group', scope)

local matched_unknown = actions.handle(instance, 'unknown_action', result, 'fg')
h.assert_true(not matched_unknown, 'unknown action was matched', scope)

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui field editor actions: OK')
