local h = require('tests.helpers')
local scope = 'hlcraft overrides'

vim.cmd('runtime plugin/hlcraft.lua')

local hlcraft = require('hlcraft')
local overrides = require('hlcraft.overrides')
local storage = require('hlcraft.storage')
local state = require('hlcraft.overrides.state')
local apply = require('hlcraft.overrides.apply')
local detail_values = require('hlcraft.ui.state.detail_values')

h.assert_true(type(state.data) == 'table', 'overrides.state does not expose mutable data', scope)
h.assert_true(type(apply.apply_all) == 'function', 'overrides.apply does not expose apply_all', scope)

local persist_dir = h.temp_dir('hlcraft-overrides')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = {
    enabled = false,
    events = {},
  },
})

vim.api.nvim_set_hl(0, 'HlcraftTestNormal', { fg = '#010203' })
vim.api.nvim_set_hl(0, 'HlcraftTestComment', { fg = '#111111' })
vim.api.nvim_set_hl(0, 'HlcraftTestDefault', { fg = '#222222' })
vim.api.nvim_set_hl(0, 'HlcraftTestClearLast', { fg = '#333333' })

overrides.clear('HlcraftTestNormal')
local group_ok, group_err = overrides.set_group('HlcraftTestNormal', 'main')
h.assert_true(group_ok, group_err or 'set_group failed', scope)
local color_ok, color_err = overrides.set_color('HlcraftTestNormal', 'fg', '#abcdef')
h.assert_true(color_ok, color_err or 'set_color failed', scope)
h.assert_equal(overrides.get('HlcraftTestNormal').fg, '#abcdef', 'runtime fg was not set', scope)
h.assert_equal(overrides.get_runtime_group('HlcraftTestNormal'), 'main', 'runtime group was not set', scope)

local original_storage_save = storage.save
---@diagnostic disable-next-line: duplicate-set-field
storage.save = function()
  return false, 'forced test failure'
end
local failed_save_ok = overrides.save()
storage.save = original_storage_save
h.assert_true(not failed_save_ok, 'failed save unexpectedly succeeded', scope)
h.assert_equal(overrides.get_persisted('HlcraftTestNormal').fg, nil, 'failed save updated persisted entry', scope)
h.assert_equal(overrides.get_persisted_group('HlcraftTestNormal'), nil, 'failed save updated persisted group', scope)
h.assert_equal(overrides.get('HlcraftTestNormal').fg, '#abcdef', 'failed save changed runtime entry', scope)

local save_ok, save_err = overrides.save()
h.assert_true(save_ok, save_err or 'save failed', scope)
h.assert_equal(
  overrides.get_persisted('HlcraftTestNormal').fg,
  '#abcdef',
  'successful save did not update persisted entry',
  scope
)
h.assert_equal(
  overrides.get_persisted_group('HlcraftTestNormal'),
  'main',
  'successful save did not update persisted group',
  scope
)

local dynamic_ok, dynamic_err = overrides.set_dynamic('HlcraftTestNormal', 'fg', {
  mode = 'rgb',
  speed = 1500,
})
h.assert_true(dynamic_ok, dynamic_err or 'set_dynamic failed', scope)
h.assert_equal(overrides.get('HlcraftTestNormal').dynamic.fg.mode, 'rgb', 'runtime dynamic mode was not set', scope)
h.assert_equal(overrides.get('HlcraftTestNormal').dynamic.fg.speed, 1500, 'runtime dynamic speed was not set', scope)

local dynamic_save_ok, dynamic_save_err = overrides.save()
h.assert_true(dynamic_save_ok, dynamic_save_err or 'dynamic save failed', scope)
local dynamic_loaded = storage.load(persist_dir)
h.assert_equal(
  dynamic_loaded.entries.HlcraftTestNormal.dynamic.fg.mode,
  'rgb',
  'saved dynamic override did not reload',
  scope
)

local clear_dynamic_ok, clear_dynamic_err = overrides.set_dynamic('HlcraftTestNormal', 'fg', nil)
h.assert_true(clear_dynamic_ok, clear_dynamic_err or 'clearing dynamic failed', scope)
h.assert_true(
  overrides.get('HlcraftTestNormal').dynamic == nil,
  'clearing last dynamic channel left dynamic table',
  scope
)

overrides.clear('HlcraftTestComment')
local group_only_ok, group_only_err = detail_values.apply_runtime(nil, 'HlcraftTestComment', { group = 'group-only' })
h.assert_true(group_only_ok, group_only_err or 'group-only apply failed', scope)
local group_only_save_ok, group_only_save_err = detail_values.save(nil, 'HlcraftTestComment')
h.assert_true(group_only_save_ok, group_only_save_err or 'group-only save failed', scope)
local loaded_group_only = storage.load(persist_dir)
h.assert_equal(loaded_group_only.groups.HlcraftTestComment, 'group-only', 'group-only group did not persist', scope)
h.assert_equal(next(loaded_group_only.entries.HlcraftTestComment), nil, 'group-only entry persisted fields', scope)

overrides.clear('HlcraftTestDefault')
local default_group_ok, default_group_err =
  detail_values.apply_runtime(nil, 'HlcraftTestDefault', { group = 'default' })
h.assert_true(default_group_ok, default_group_err or 'explicit default group apply failed', scope)
local default_save_ok, default_save_err = detail_values.save(nil, 'HlcraftTestDefault')
h.assert_true(default_save_ok, default_save_err or 'explicit default group save failed', scope)
h.assert_true(h.list_contains(overrides.known_groups(), 'default'), 'explicit default group was not listed', scope)

overrides.clear('HlcraftTestClearLast')
local clear_group_ok, clear_group_err =
  detail_values.apply_runtime(nil, 'HlcraftTestClearLast', { group = 'clear-last' })
h.assert_true(clear_group_ok, clear_group_err or 'clear-last group apply failed', scope)
local clear_color_ok, clear_color_err = detail_values.apply_runtime(nil, 'HlcraftTestClearLast', { fg = '#123456' })
h.assert_true(clear_color_ok, clear_color_err or 'clear-last color apply failed', scope)
local unset_color_ok, unset_color_err = detail_values.apply_runtime(nil, 'HlcraftTestClearLast', { fg = vim.NIL })
h.assert_true(unset_color_ok, unset_color_err or 'clear-last unset failed', scope)
h.assert_equal(
  overrides.get_runtime_group('HlcraftTestClearLast'),
  'clear-last',
  'clearing last field dropped runtime group',
  scope
)
h.assert_equal(next(overrides.get('HlcraftTestClearLast')), nil, 'clearing last field left runtime fields', scope)

overrides.bootstrap(true)
h.assert_equal(
  overrides.get_persisted('HlcraftTestNormal').fg,
  '#abcdef',
  'bootstrap did not reload persisted entry',
  scope
)
h.assert_equal(
  overrides.get_persisted_group('HlcraftTestNormal'),
  'main',
  'bootstrap did not reload persisted group',
  scope
)
h.assert_equal(
  overrides.get_persisted_group('HlcraftTestComment'),
  'group-only',
  'bootstrap did not reload group-only persisted group',
  scope
)

vim.fn.delete(persist_dir, 'rf')
print('hlcraft overrides: OK')
