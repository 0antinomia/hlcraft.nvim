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

local loaded = storage.load(persist_dir)
h.assert_equal(loaded.entries.HlcraftEngineNormal.fg, '#abcdef', 'saved fg did not load', scope)

vim.fn.delete(persist_dir, 'rf')

print('hlcraft engine: OK')
