local h = require('tests.helpers')
local scope = 'hlcraft engine'

vim.cmd('runtime plugin/hlcraft.lua')

local hlcraft = require('hlcraft')
local engine = require('hlcraft.engine.service')
local storage = require('hlcraft.persistence.repository')

local persist_dir = h.temp_dir('hlcraft-engine')
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

vim.api.nvim_set_hl(0, 'HlcraftEngineNormal', { fg = '#010203' })

local group_ok, group_err = engine.set_group('HlcraftEngineNormal', 'engine')
h.assert_true(group_ok, group_err or 'set_group failed', scope)

local bad_group_ok, bad_group_err = engine.set_group('HlcraftEngineBadGroup', 42)
h.assert_true(not bad_group_ok, 'numeric group was accepted', scope)
h.assert_equal(bad_group_err, 'Group name must be a string', 'numeric group reported wrong error', scope)
h.assert_true(engine.get_draft_group('HlcraftEngineBadGroup') == nil, 'invalid group created draft group', scope)

local color_ok, color_err = engine.set_color('HlcraftEngineNormal', 'fg', '#abcdef')
h.assert_true(color_ok, color_err or 'set_color failed', scope)
h.assert_equal(engine.get('HlcraftEngineNormal').fg, '#abcdef', 'draft fg was not set', scope)
h.assert_true(engine.get_persisted('HlcraftEngineNormal').fg == nil, 'draft leaked into persisted state', scope)

local save_ok, save_err = engine.save()
h.assert_true(save_ok, save_err or 'save failed', scope)
h.assert_equal(engine.get_persisted('HlcraftEngineNormal').fg, '#abcdef', 'save did not update persisted fg', scope)

local dynamic_ok, dynamic_err = engine.set_dynamic('HlcraftEngineNormal', 'fg', {
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
  engine.get('HlcraftEngineNormal').dynamic.fg.timeline[2].color,
  '#ffffff',
  'dynamic draft did not set',
  scope
)

engine.restore_persisted('HlcraftEngineNormal')
h.assert_true(engine.get('HlcraftEngineNormal').dynamic == nil, 'restore did not discard unsaved dynamic draft', scope)
h.assert_equal(engine.get('HlcraftEngineNormal').fg, '#abcdef', 'restore did not recover persisted fg', scope)

local before_bad_dynamic = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local before_bad_dynamic_group = engine.get_draft_group('HlcraftEngineNormal')
local bad_ok = engine.set_dynamic('HlcraftEngineNormal', 'fg', {
  timeline = {
    { at = 0, color = 'base' },
  },
})
h.assert_true(not bad_ok, 'invalid dynamic mutation was accepted', scope)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_bad_dynamic),
  'invalid dynamic mutation changed draft state',
  scope
)
h.assert_equal(
  engine.get_draft_group('HlcraftEngineNormal'),
  before_bad_dynamic_group,
  'invalid dynamic mutation changed draft group',
  scope
)

local before_bad_color = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local before_bad_color_group = engine.get_draft_group('HlcraftEngineNormal')
local bad_color_ok = engine.set_color('HlcraftEngineNormal', 'fg', 'not-a-color')
h.assert_true(not bad_color_ok, 'invalid color mutation was accepted', scope)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_bad_color),
  'invalid color mutation changed draft state',
  scope
)
h.assert_equal(
  engine.get_draft_group('HlcraftEngineNormal'),
  before_bad_color_group,
  'invalid color mutation changed draft group',
  scope
)

local before_clear_group_patch = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local before_clear_group_patch_group = engine.get_draft_group('HlcraftEngineNormal')
local clear_group_patch_ok, clear_group_patch_err =
  engine.apply_patch('HlcraftEngineNormal', { group = vim.NIL, fg = '#ffffff' })
h.assert_true(not clear_group_patch_ok, 'group clearing with non-empty override was accepted', scope)
h.assert_true(type(clear_group_patch_err) == 'string', 'group clearing returned no error', scope)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_clear_group_patch),
  'group clearing with non-empty override changed draft state',
  scope
)
h.assert_equal(
  engine.get_draft_group('HlcraftEngineNormal'),
  before_clear_group_patch_group,
  'group clearing with non-empty override changed draft group',
  scope
)

local loaded = storage.load(persist_dir)
h.assert_equal(loaded.entries.HlcraftEngineNormal.fg, '#abcdef', 'saved fg did not load', scope)

local group_only_ok, group_only_err = engine.set_group('HlcraftEngineGroupOnly', 'engine-group-only')
h.assert_true(group_only_ok, group_only_err or 'group-only set_group failed', scope)
local group_only_save_ok, group_only_save_err = engine.save()
h.assert_true(group_only_save_ok, group_only_save_err or 'group-only save failed', scope)
h.assert_equal(
  engine.get_persisted_group('HlcraftEngineGroupOnly'),
  'engine-group-only',
  'group-only entry did not save',
  scope
)

local clear_group_only_ok, clear_group_only_err = engine.apply_patch('HlcraftEngineGroupOnly', { group = vim.NIL })
h.assert_true(clear_group_only_ok, clear_group_only_err or 'group-only clear failed', scope)
h.assert_equal(
  engine.get_draft_group('HlcraftEngineGroupOnly'),
  nil,
  'cleared group-only draft still falls back to persisted group',
  scope
)
local clear_group_only_save_ok, clear_group_only_save_err = engine.save()
h.assert_true(clear_group_only_save_ok, clear_group_only_save_err or 'cleared group-only save failed', scope)
local loaded_after_group_clear = storage.load(persist_dir)
h.assert_equal(
  loaded_after_group_clear.groups.HlcraftEngineGroupOnly,
  nil,
  'cleared group-only entry was still persisted',
  scope
)

h.cleanup_dir(persist_dir)

print('hlcraft engine: OK')
