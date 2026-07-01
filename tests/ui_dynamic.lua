local h = require('tests.helpers')
local scope = 'hlcraft ui dynamic'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local editor = require('hlcraft.ui.editor.dynamic')
local engine = require('hlcraft.engine.service')

local persist_dir = h.temp_dir('hlcraft-ui-dynamic')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, 'HlcraftUiDynamicNormal', { fg = '#101010' })
engine.set_group('HlcraftUiDynamicNormal', 'ui-dynamic')

local instance = {
  state = {},
  rerender = function() end,
}
local result = { name = 'HlcraftUiDynamicNormal' }

local toggle_ok, toggle_err = editor.toggle(instance, result, 'fg')
h.assert_true(toggle_ok, toggle_err or 'toggle dynamic failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset, 'pulse', 'toggle did not create pulse preset', scope)

local cycle_ok, cycle_err = editor.cycle_preset(instance, result, 'fg')
h.assert_true(cycle_ok, cycle_err or 'cycle preset failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset, 'breath', 'cycle did not move to breath preset', scope)

local duration_ok, duration_err = editor.adjust_duration(instance, result, 'fg', 250)
h.assert_true(duration_ok, duration_err or 'duration adjust failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.duration, 2250, 'duration did not adjust', scope)

local loop_ok, loop_err = editor.set_loop(instance, result, 'fg', 'once')
h.assert_true(loop_ok, loop_err or 'loop set failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.loop, 'once', 'loop did not set', scope)

local phase_ok, phase_err = editor.set_phase(instance, result, 'fg', '0.5')
h.assert_true(phase_ok, phase_err or 'phase set failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.phase, 0.5, 'phase did not set', scope)

local raw_ok, raw_err = editor.set_raw_json(instance, result, 'fg', vim.json.encode({
  version = 1,
  preset = 'manual',
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
    { at = 1, color = '#ffffff' },
  },
}))
h.assert_true(raw_ok, raw_err or 'raw json set failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset, 'manual', 'raw json preset did not set', scope)

local bad_raw_ok = editor.set_raw_json(instance, result, 'fg', '{bad json')
h.assert_true(not bad_raw_ok, 'invalid raw json was accepted', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset, 'manual', 'invalid raw json changed draft', scope)

vim.fn.delete(persist_dir, 'rf')
config.setup({})

print('hlcraft ui dynamic: OK')
