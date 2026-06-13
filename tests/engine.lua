local h = require('tests.helpers')
local scope = 'hlcraft engine'

vim.cmd('runtime plugin/hlcraft.lua')

local hlcraft = require('hlcraft')
local engine = require('hlcraft.engine.service')
local storage = require('hlcraft.persistence.repository')

local persist_dir = h.temp_dir('hlcraft-engine')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, 'HlcraftEngineNormal', { fg = '#010203' })

local group_ok, group_err = engine.set_group('HlcraftEngineNormal', 'engine')
h.assert_true(group_ok, group_err or 'set_group failed', scope)

local color_ok, color_err = engine.set_color('HlcraftEngineNormal', 'fg', '#abcdef')
h.assert_true(color_ok, color_err or 'set_color failed', scope)
h.assert_equal(engine.get('HlcraftEngineNormal').fg, '#abcdef', 'draft fg was not set', scope)
h.assert_true(engine.get_persisted('HlcraftEngineNormal').fg == nil, 'draft leaked into persisted state', scope)

local save_ok, save_err = engine.save()
h.assert_true(save_ok, save_err or 'save failed', scope)
h.assert_equal(engine.get_persisted('HlcraftEngineNormal').fg, '#abcdef', 'save did not update persisted fg', scope)

local dynamic_ok, dynamic_err = engine.set_dynamic('HlcraftEngineNormal', 'fg', {
  mode = 'rgb',
  speed = 1500,
  palette = { '#000000', '#ffffff' },
})
h.assert_true(dynamic_ok, dynamic_err or 'set_dynamic failed', scope)
h.assert_equal(engine.get('HlcraftEngineNormal').dynamic.fg.palette[2], '#ffffff', 'dynamic draft did not set', scope)

engine.restore_persisted('HlcraftEngineNormal')
h.assert_true(engine.get('HlcraftEngineNormal').dynamic == nil, 'restore did not discard unsaved dynamic draft', scope)
h.assert_equal(engine.get('HlcraftEngineNormal').fg, '#abcdef', 'restore did not recover persisted fg', scope)

local before_bad_dynamic = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local bad_ok = engine.set_dynamic('HlcraftEngineNormal', 'fg', { mode = 'bad-mode' })
h.assert_true(not bad_ok, 'invalid dynamic mutation was accepted', scope)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_bad_dynamic),
  'invalid dynamic mutation changed draft state',
  scope
)

local before_bad_color = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local bad_color_ok = engine.set_color('HlcraftEngineNormal', 'fg', 'not-a-color')
h.assert_true(not bad_color_ok, 'invalid color mutation was accepted', scope)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_bad_color),
  'invalid color mutation changed draft state',
  scope
)

local before_bad_patch_key = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local before_bad_patch_key_group = engine.get_draft_group('HlcraftEngineNormal')
local bad_patch_key_ok, bad_patch_key_err = engine.apply_patch('HlcraftEngineNormal', { bogus = true })
h.assert_true(not bad_patch_key_ok, 'unsupported patch key was accepted', scope)
h.assert_true(
  type(bad_patch_key_err) == 'string' and bad_patch_key_err:find('Unsupported override key: bogus', 1, true) ~= nil,
  'unsupported patch key returned unclear error: ' .. tostring(bad_patch_key_err),
  scope
)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_bad_patch_key),
  'unsupported patch key changed draft state',
  scope
)
h.assert_equal(
  engine.get_draft_group('HlcraftEngineNormal'),
  before_bad_patch_key_group,
  'unsupported patch key changed draft group',
  scope
)

local before_bad_patch_dynamic = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local before_bad_patch_dynamic_group = engine.get_draft_group('HlcraftEngineNormal')
local bad_patch_dynamic_ok, bad_patch_dynamic_err = engine.apply_patch('HlcraftEngineNormal', {
  dynamic = {
    bogus = { mode = 'rgb' },
  },
})
h.assert_true(not bad_patch_dynamic_ok, 'unsupported dynamic patch key was accepted', scope)
h.assert_true(
  type(bad_patch_dynamic_err) == 'string'
    and bad_patch_dynamic_err:find('Unsupported dynamic key: bogus', 1, true) ~= nil,
  'unsupported dynamic patch key returned unclear error: ' .. tostring(bad_patch_dynamic_err),
  scope
)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_bad_patch_dynamic),
  'unsupported dynamic patch key changed draft state',
  scope
)
h.assert_equal(
  engine.get_draft_group('HlcraftEngineNormal'),
  before_bad_patch_dynamic_group,
  'unsupported dynamic patch key changed draft group',
  scope
)

local before_clear_group_patch = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local before_clear_group_patch_group = engine.get_draft_group('HlcraftEngineNormal')
local clear_group_patch_ok, clear_group_patch_err =
  engine.apply_patch('HlcraftEngineNormal', { group = vim.NIL, fg = '#ffffff' })
h.assert_true(not clear_group_patch_ok, 'group clearing with non-empty override was accepted', scope)
h.assert_true(
  type(clear_group_patch_err) == 'string' and clear_group_patch_err:find('Group name is required', 1, true) ~= nil,
  'group clearing with non-empty override returned unclear error: ' .. tostring(clear_group_patch_err),
  scope
)
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

local before_malformed_patch = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local before_malformed_patch_group = engine.get_draft_group('HlcraftEngineNormal')
local nil_patch_ok, nil_patch_err = engine.apply_patch('HlcraftEngineNormal', nil)
h.assert_true(not nil_patch_ok, 'nil patch was accepted', scope)
h.assert_true(
  type(nil_patch_err) == 'string' and nil_patch_err:find('Patch must be a table', 1, true) ~= nil,
  'nil patch returned unclear error: ' .. tostring(nil_patch_err),
  scope
)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_malformed_patch),
  'nil patch changed draft state',
  scope
)
h.assert_equal(
  engine.get_draft_group('HlcraftEngineNormal'),
  before_malformed_patch_group,
  'nil patch changed draft group',
  scope
)

local malformed_patch_ok, malformed_patch_err = engine.apply_patch('HlcraftEngineNormal', 'bad')
h.assert_true(not malformed_patch_ok, 'malformed patch was accepted', scope)
h.assert_true(
  type(malformed_patch_err) == 'string' and malformed_patch_err:find('Patch must be a table', 1, true) ~= nil,
  'malformed patch returned unclear error: ' .. tostring(malformed_patch_err),
  scope
)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_malformed_patch),
  'malformed patch changed draft state',
  scope
)
h.assert_equal(
  engine.get_draft_group('HlcraftEngineNormal'),
  before_malformed_patch_group,
  'malformed patch changed draft group',
  scope
)

local before_malformed_dynamic_patch = vim.deepcopy(engine.get('HlcraftEngineNormal'))
local before_malformed_dynamic_patch_group = engine.get_draft_group('HlcraftEngineNormal')
local malformed_dynamic_patch_ok, malformed_dynamic_patch_err =
  engine.apply_patch('HlcraftEngineNormal', { dynamic = 'bad' })
h.assert_true(not malformed_dynamic_patch_ok, 'malformed dynamic patch was accepted', scope)
h.assert_true(
  type(malformed_dynamic_patch_err) == 'string'
    and malformed_dynamic_patch_err:find('dynamic patch must be a table', 1, true) ~= nil,
  'malformed dynamic patch returned unclear error: ' .. tostring(malformed_dynamic_patch_err),
  scope
)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftEngineNormal'), before_malformed_dynamic_patch),
  'malformed dynamic patch changed draft state',
  scope
)
h.assert_equal(
  engine.get_draft_group('HlcraftEngineNormal'),
  before_malformed_dynamic_patch_group,
  'malformed dynamic patch changed draft group',
  scope
)

local loaded = storage.load(persist_dir)
h.assert_equal(loaded.entries.HlcraftEngineNormal.fg, '#abcdef', 'saved fg did not load', scope)

vim.fn.delete(persist_dir, 'rf')

print('hlcraft engine: OK')
