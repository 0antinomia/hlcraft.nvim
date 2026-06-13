local h = require('tests.helpers')
local scope = 'hlcraft ui session'

vim.cmd('runtime plugin/hlcraft.lua')

local hlcraft = require('hlcraft')
local engine = require('hlcraft.engine.service')
local session = require('hlcraft.ui.session')
local storage = require('hlcraft.persistence.repository')

local persist_dir = h.temp_dir('hlcraft-ui-session')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, 'HlcraftSessionNormal', { fg = '#010203', bg = '#111111' })

local group_ok, group_err = session.apply_patch(nil, 'HlcraftSessionNormal', { group = 'session' })
h.assert_true(group_ok, group_err or 'session group patch failed', scope)

local fg_ok, fg_err = session.apply_patch(nil, 'HlcraftSessionNormal', {
  fg = '#abcdef',
  dynamic = {
    fg = {
      mode = 'rgb',
      speed = 1500,
      palette = { '#000000', '#ffffff' },
    },
  },
})
h.assert_true(fg_ok, fg_err or 'session fg patch failed', scope)

local bg_ok, bg_err = session.apply_patch(nil, 'HlcraftSessionNormal', {
  bg = '#123456',
  dynamic = {
    bg = {
      mode = 'breath',
      speed = 1000,
      palette = { '#111111', '#222222' },
    },
  },
})
h.assert_true(bg_ok, bg_err or 'session bg patch failed', scope)

h.assert_equal(session.draft_entry('HlcraftSessionNormal').fg, '#abcdef', 'draft_entry did not read draft fg', scope)
h.assert_equal(
  session.runtime_entry('HlcraftSessionNormal').bg,
  '#123456',
  'runtime_entry alias did not read draft bg',
  scope
)
h.assert_equal(session.draft_group('HlcraftSessionNormal'), 'session', 'draft_group did not read draft group', scope)
h.assert_equal(
  session.runtime_group('HlcraftSessionNormal'),
  'session',
  'runtime_group alias did not read draft group',
  scope
)
h.assert_equal(
  session.display_group('HlcraftSessionNormal'),
  'session',
  'display_group did not read draft group',
  scope
)
h.assert_equal(
  session.display_value('HlcraftSessionNormal', 'fg', '#000000'),
  '#abcdef',
  'display_value did not prefer draft value',
  scope
)
h.assert_equal(
  session.display_value('HlcraftSessionNormal', 'sp', '#000000'),
  '#000000',
  'display_value did not return fallback for unset field',
  scope
)
h.assert_equal(
  session.dynamic_value('HlcraftSessionNormal', 'fg').palette[2],
  '#ffffff',
  'dynamic_value did not preserve prior dynamic fg channel',
  scope
)
h.assert_equal(
  session.dynamic_value('HlcraftSessionNormal', 'bg').mode,
  'breath',
  'dynamic_value did not read later dynamic bg channel',
  scope
)
h.assert_equal(
  session.display_color_value('HlcraftSessionNormal', 'fg', '#000000'),
  'dynamic:rgb 1500ms',
  'display_color_value did not format dynamic channel',
  scope
)
h.assert_true(session.is_dirty('HlcraftSessionNormal'), 'draft edit was not dirty before save', scope)

local invalid_before = vim.deepcopy(engine.get('HlcraftSessionNormal'))
local invalid_ok = session.apply_patch(nil, 'HlcraftSessionNormal', { fg = 'not-a-color' })
h.assert_true(not invalid_ok, 'invalid patch was accepted', scope)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftSessionNormal'), invalid_before),
  'invalid session patch changed draft state',
  scope
)

local save_ok, save_err = session.save(nil, 'HlcraftSessionNormal')
h.assert_true(save_ok, save_err or 'session save failed', scope)
h.assert_true(not session.is_dirty('HlcraftSessionNormal'), 'saved session remained dirty', scope)
h.assert_equal(
  session.persisted_entry('HlcraftSessionNormal').dynamic.fg.mode,
  'rgb',
  'persisted_entry did not read saved dynamic fg',
  scope
)
h.assert_equal(
  session.persisted_group('HlcraftSessionNormal'),
  'session',
  'persisted_group did not read saved group',
  scope
)

local edit_ok, edit_err = session.apply_runtime(nil, 'HlcraftSessionNormal', { fg = '#654321' })
h.assert_true(edit_ok, edit_err or 'apply_runtime alias failed', scope)
h.assert_true(session.is_dirty('HlcraftSessionNormal'), 'runtime alias edit was not dirty', scope)
session.discard(nil, 'HlcraftSessionNormal')
h.assert_equal(session.draft_entry('HlcraftSessionNormal').fg, '#abcdef', 'discard did not restore persisted fg', scope)
h.assert_true(not session.is_dirty('HlcraftSessionNormal'), 'discarded session remained dirty', scope)

local loaded = storage.load(persist_dir)
h.assert_equal(loaded.entries.HlcraftSessionNormal.fg, '#abcdef', 'saved session fg did not load', scope)
h.assert_equal(loaded.groups.HlcraftSessionNormal, 'session', 'saved session group did not load', scope)

vim.fn.delete(persist_dir, 'rf')

print('hlcraft ui session: OK')
