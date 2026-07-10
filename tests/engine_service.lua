local h = require('tests.helpers')
local scope = 'hlcraft engine service'

local engine = require('hlcraft.engine.service')
local store = require('hlcraft.engine.store')

local function with_entry_state(fn)
  local original_draft = vim.deepcopy(store.data.draft)
  local original_persisted = vim.deepcopy(store.data.persisted)
  local original_draft_groups = vim.deepcopy(store.data.draft_groups)
  local original_persisted_groups = vim.deepcopy(store.data.persisted_groups)

  local ok, err = xpcall(fn, debug.traceback)

  store.data.draft = original_draft
  store.data.persisted = original_persisted
  store.data.draft_groups = original_draft_groups
  store.data.persisted_groups = original_persisted_groups

  if not ok then
    error(err, 0)
  end
end

with_entry_state(function()
  h.assert_true(next(engine.get('HlcraftEngineServiceMissing')) == nil, 'missing draft entry was not empty', scope)
  h.assert_true(
    next(engine.get_persisted('HlcraftEngineServiceMissing')) == nil,
    'missing persisted entry was not empty',
    scope
  )

  store.data.draft.HlcraftEngineServiceBrokenDraft = false
  local bad_draft_ok = pcall(engine.get, 'HlcraftEngineServiceBrokenDraft')
  h.assert_true(not bad_draft_ok, 'engine service accepted invalid draft entry', scope)

  store.data.draft.HlcraftEngineServiceInvalidDynamic = {
    dynamic = {
      fg = {
        version = 1,
        timeline = {},
      },
    },
  }
  local invalid_dynamic_ok = pcall(engine.get, 'HlcraftEngineServiceInvalidDynamic')
  h.assert_true(not invalid_dynamic_ok, 'engine service accepted invalid draft dynamic entry', scope)

  store.data.draft.HlcraftEngineServiceNormalizeDraft = {
    fg = '#ABCDEF',
  }
  h.assert_equal(
    engine.get('HlcraftEngineServiceNormalizeDraft').fg,
    '#abcdef',
    'engine service did not normalize draft reads',
    scope
  )

  store.data.persisted.HlcraftEngineServiceBrokenPersisted = false
  local bad_persisted_ok = pcall(engine.get_persisted, 'HlcraftEngineServiceBrokenPersisted')
  h.assert_true(not bad_persisted_ok, 'engine service accepted invalid persisted entry', scope)

  store.data.draft_groups.HlcraftEngineServiceBrokenDraftGroup = false
  local bad_draft_group_ok = pcall(engine.get_draft_group, 'HlcraftEngineServiceBrokenDraftGroup')
  h.assert_true(not bad_draft_group_ok, 'engine service accepted invalid draft group', scope)
  store.data.draft_groups.HlcraftEngineServiceBrokenDraftGroup = nil

  store.data.draft_groups.HlcraftEngineServiceSpacedDraftGroup = ' service '
  h.assert_equal(
    engine.get_draft_group('HlcraftEngineServiceSpacedDraftGroup'),
    'service',
    'engine service did not normalize draft group reads',
    scope
  )
  h.assert_true(
    vim.tbl_contains(engine.known_groups(), 'service'),
    'engine service known groups did not normalize draft groups',
    scope
  )

  store.data.persisted_groups.HlcraftEngineServiceEmptyPersistedGroup = ' '
  local empty_persisted_group_ok = pcall(engine.get_persisted_group, 'HlcraftEngineServiceEmptyPersistedGroup')
  h.assert_true(not empty_persisted_group_ok, 'engine service accepted empty persisted group', scope)

  local nil_name_ok = pcall(engine.get, nil)
  h.assert_true(not nil_name_ok, 'engine service accepted nil highlight name', scope)
  local empty_name_ok = pcall(engine.apply_patch, '', { fg = '#ffffff' })
  h.assert_true(not empty_name_ok, 'engine service accepted empty highlight name', scope)
  local spaced_name_ok = pcall(engine.get, 'Bad Name')
  h.assert_true(not spaced_name_ok, 'engine service accepted whitespace in highlight name', scope)
  local command_name_ok = pcall(engine.apply_patch, 'Bad|Name', { fg = '#ffffff' })
  h.assert_true(not command_name_ok, 'engine service accepted command separators in highlight name', scope)
  local invalid_color_key_ok, invalid_color_key_err = engine.set_color('HlcraftEngineServiceKey', nil, '#ffffff')
  h.assert_true(not invalid_color_key_ok, 'engine service accepted nil color key', scope)
  h.assert_equal(invalid_color_key_err, 'Unsupported override key: nil', 'nil color key error changed', scope)
  local invalid_dynamic_key_ok, invalid_dynamic_key_err = engine.set_dynamic('HlcraftEngineServiceKey', false, nil)
  h.assert_true(not invalid_dynamic_key_ok, 'engine service accepted boolean dynamic key', scope)
  h.assert_equal(invalid_dynamic_key_err, 'Unsupported dynamic key: false', 'boolean dynamic key error changed', scope)
  local invalid_style_key_ok, invalid_style_key_err = engine.set_style('HlcraftEngineServiceKey', 1, true)
  h.assert_true(not invalid_style_key_ok, 'engine service accepted numeric style key', scope)
  h.assert_equal(invalid_style_key_err, 'Unsupported style key: 1', 'numeric style key error changed', scope)
end)

print('hlcraft engine service: OK')
