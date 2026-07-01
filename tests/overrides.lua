local h = require('tests.helpers')
local scope = 'hlcraft overrides'

vim.cmd('runtime plugin/hlcraft.lua')

local hlcraft = require('hlcraft')
local overrides = require('hlcraft.overrides')
local storage = require('hlcraft.storage')

local persist_dir = h.temp_dir('hlcraft-overrides')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, 'HlcraftTestNormal', { fg = '#010203' })

local group_ok, group_err = overrides.set_group('HlcraftTestNormal', 'main')
h.assert_true(group_ok, group_err or 'set_group failed', scope)
local color_ok, color_err = overrides.set_color('HlcraftTestNormal', 'fg', '#abcdef')
h.assert_true(color_ok, color_err or 'set_color failed', scope)
h.assert_equal(overrides.get('HlcraftTestNormal').fg, '#abcdef', 'runtime fg was not set', scope)
h.assert_equal(overrides.get_runtime_group('HlcraftTestNormal'), 'main', 'runtime group was not set', scope)
h.assert_true(overrides.get_persisted('HlcraftTestNormal').fg == nil, 'runtime edit was persisted before save', scope)

local save_ok, save_err = overrides.save()
h.assert_true(save_ok, save_err or 'save failed', scope)
h.assert_equal(overrides.get_persisted('HlcraftTestNormal').fg, '#abcdef', 'save did not update persisted entry', scope)
h.assert_equal(overrides.get_persisted_group('HlcraftTestNormal'), 'main', 'save did not update persisted group', scope)

local dynamic_ok, dynamic_err = overrides.set_dynamic('HlcraftTestNormal', 'fg', {
  version = 1,
  preset = 'pulse',
  duration = 1500,
  loop = 'pingpong',
  timeline = {
    { at = 0, color = 'base' },
    { at = 1, color = '#ffffff' },
  },
})
h.assert_true(dynamic_ok, dynamic_err or 'set_dynamic failed', scope)
h.assert_equal(
  overrides.get('HlcraftTestNormal').dynamic.fg.preset,
  'pulse',
  'runtime dynamic preset was not set',
  scope
)

local before_legacy_dynamic = vim.deepcopy(overrides.get('HlcraftTestNormal').dynamic)
local legacy_ok = overrides.set_dynamic('HlcraftTestNormal', 'fg', {
  mode = 'rgb',
  speed = 1500,
  palette = { '#000000', '#ffffff' },
})
h.assert_true(not legacy_ok, 'legacy dynamic mutation was accepted', scope)
h.assert_true(
  vim.deep_equal(overrides.get('HlcraftTestNormal').dynamic, before_legacy_dynamic),
  'legacy dynamic mutation changed runtime dynamic config',
  scope
)

local dynamic_save_ok, dynamic_save_err = overrides.save()
h.assert_true(dynamic_save_ok, dynamic_save_err or 'dynamic save failed', scope)

local loaded = storage.load(persist_dir)
h.assert_equal(loaded.entries.HlcraftTestNormal.fg, '#abcdef', 'saved override did not load from storage', scope)
h.assert_equal(
  loaded.entries.HlcraftTestNormal.dynamic.fg.timeline[2].color,
  '#ffffff',
  'saved dynamic did not load from storage',
  scope
)

overrides.bootstrap(true)
h.assert_equal(
  overrides.get_persisted('HlcraftTestNormal').fg,
  '#abcdef',
  'bootstrap did not reload persisted fg',
  scope
)
h.assert_equal(
  overrides.get_persisted('HlcraftTestNormal').dynamic.fg.duration,
  1500,
  'bootstrap did not reload persisted dynamic duration',
  scope
)

local clear_dynamic_ok, clear_dynamic_err = overrides.set_dynamic('HlcraftTestNormal', 'fg', nil)
h.assert_true(clear_dynamic_ok, clear_dynamic_err or 'clearing dynamic failed', scope)
h.assert_true(
  overrides.get('HlcraftTestNormal').dynamic == nil,
  'clearing last dynamic channel left dynamic table',
  scope
)

vim.fn.delete(persist_dir, 'rf')

print('hlcraft overrides: OK')
