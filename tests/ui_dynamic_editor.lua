local h = require('tests.helpers')
local scope = 'hlcraft ui dynamic editor'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local dynamic_model = require('hlcraft.dynamic.model')
local editor = require('hlcraft.ui.editor.dynamic')
local engine = require('hlcraft.engine.service')

local name = 'HlcraftUiDynamicEditorNormal'
local persist_dir = h.temp_dir('hlcraft-ui-dynamic-editor')
hlcraft.setup({
  persistence = {
    dir = persist_dir,
    reapply_events = {
      enabled = false,
    },
  },
  search = {
    debounce_ms = 0,
  },
})

vim.api.nvim_set_hl(0, name, { fg = '#101010' })
engine.set_group(name, 'ui-dynamic-editor')

local instance = {
  state = {},
  rerender = function() end,
}
local result = { name = name }

local toggle_ok, toggle_err = editor.toggle(instance, result, 'fg')
h.assert_true(toggle_ok, toggle_err or 'toggle dynamic failed', scope)
h.assert_equal(engine.get(name).dynamic.fg.preset, 'pulse', 'toggle did not create pulse preset', scope)
local clear_toggle_ok, clear_toggle_err = editor.toggle(instance, result, 'fg')
h.assert_true(clear_toggle_ok, clear_toggle_err or 'toggle dynamic clear failed', scope)
h.assert_true(engine.get(name).dynamic == nil, 'toggle did not clear dynamic field', scope)
local reset_toggle_ok, reset_toggle_err = editor.toggle(instance, result, 'fg')
h.assert_true(reset_toggle_ok, reset_toggle_err or 'toggle dynamic reset failed', scope)
h.assert_equal(engine.get(name).dynamic.fg.preset, 'pulse', 'toggle did not recreate pulse preset', scope)

local cycle_ok, cycle_err = editor.cycle_preset(instance, result, 'fg')
h.assert_true(cycle_ok, cycle_err or 'cycle preset failed', scope)
h.assert_equal(engine.get(name).dynamic.fg.preset, 'breath', 'cycle did not move to breath preset', scope)

local duration_ok, duration_err = editor.adjust_duration(instance, result, 'fg', 250)
h.assert_true(duration_ok, duration_err or 'duration adjust failed', scope)
h.assert_equal(engine.get(name).dynamic.fg.duration, 2250, 'duration did not adjust', scope)

local loop_ok, loop_err = editor.set_loop(instance, result, 'fg', 'once')
h.assert_true(loop_ok, loop_err or 'loop set failed', scope)
h.assert_equal(engine.get(name).dynamic.fg.loop, 'once', 'loop did not set', scope)
local bad_loop_ok, bad_loop_err = editor.set_loop(instance, result, 'fg', 'bad')
h.assert_true(not bad_loop_ok, 'invalid loop set succeeded', scope)
h.assert_true(tostring(bad_loop_err):find('Loop must be one of:', 1, true) ~= nil, 'invalid loop error changed', scope)
h.assert_equal(engine.get(name).dynamic.fg.loop, 'once', 'invalid loop changed draft', scope)

local phase_ok, phase_err = editor.set_phase(instance, result, 'fg', '0.5')
h.assert_true(phase_ok, phase_err or 'phase set failed', scope)
h.assert_equal(engine.get(name).dynamic.fg.phase, 0.5, 'phase did not set', scope)

local raw_ok, raw_err = editor.set_raw_json(
  instance,
  result,
  'fg',
  vim.json.encode({
    version = 1,
    preset = 'manual',
    duration = 1000,
    loop = 'repeat',
    timeline = {
      { at = 0, color = 'base' },
      { at = 1, color = '#ffffff' },
    },
  })
)
h.assert_true(raw_ok, raw_err or 'raw json set failed', scope)
h.assert_equal(engine.get(name).dynamic.fg.preset, 'manual', 'raw json preset did not set', scope)

local compact_raw_ok, compact_raw_err = editor.set_raw_json(
  instance,
  result,
  'fg',
  vim.json.encode({
    version = 1,
    timeline = {
      { at = 0, color = 'base' },
    },
  })
)
h.assert_true(compact_raw_ok, compact_raw_err or 'compact raw json set failed', scope)
h.assert_equal(
  engine.get(name).dynamic.fg.duration,
  dynamic_model.default_duration,
  'compact raw json did not normalize duration',
  scope
)

local compact_duration_ok, compact_duration_err = editor.adjust_duration(instance, result, 'fg', 100)
h.assert_true(compact_duration_ok, compact_duration_err or 'compact duration adjust failed', scope)
h.assert_equal(
  engine.get(name).dynamic.fg.duration,
  dynamic_model.default_duration + 100,
  'duration adjust did not rely on normalized value',
  scope
)
local bad_duration_delta_ok, bad_duration_delta_err = editor.adjust_duration(instance, result, 'fg', 0 / 0)
h.assert_true(not bad_duration_delta_ok, 'duration adjust accepted NaN delta', scope)
h.assert_equal(
  bad_duration_delta_err,
  'Duration adjustment delta must be a finite number',
  'duration adjust NaN error changed',
  scope
)
h.assert_equal(
  engine.get(name).dynamic.fg.duration,
  dynamic_model.default_duration + 100,
  'duration adjust NaN changed draft',
  scope
)

local before_bad_json = vim.deepcopy(engine.get(name).dynamic.fg)
local bad_schema_ok = editor.set_raw_json(
  instance,
  result,
  'fg',
  vim.json.encode({
    version = 1,
    loop = 'bad',
    timeline = {
      { at = 0, color = 'base' },
    },
  })
)
h.assert_true(not bad_schema_ok, 'invalid dynamic JSON schema was accepted', scope)
h.assert_true(vim.deep_equal(engine.get(name).dynamic.fg, before_bad_json), 'invalid JSON schema changed draft', scope)

local bad_raw_ok = editor.set_raw_json(instance, result, 'fg', '{bad json')
h.assert_true(not bad_raw_ok, 'invalid raw json was accepted', scope)
h.assert_true(vim.deep_equal(engine.get(name).dynamic.fg, before_bad_json), 'invalid raw json changed draft', scope)
local invalid_editor_result_ok = pcall(editor.toggle, instance, {}, 'fg')
h.assert_true(not invalid_editor_result_ok, 'dynamic editor accepted a nameless result', scope)
local invalid_editor_field_ok = pcall(editor.cycle_preset, instance, result, false)
h.assert_true(not invalid_editor_field_ok, 'dynamic editor accepted an invalid field', scope)
local invalid_editor_raw_text_ok = pcall(editor.set_raw_json, instance, result, 'fg', false)
h.assert_true(not invalid_editor_raw_text_ok, 'dynamic editor accepted non-string raw JSON text', scope)

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui dynamic editor: OK')
