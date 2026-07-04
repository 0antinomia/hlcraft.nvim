local h = require('tests.helpers')
local scope = 'hlcraft ui keymap commands'

local commands = require('hlcraft.ui.keymap_commands')
local config = require('hlcraft.config')
local engine = require('hlcraft.engine.service')
local hlcraft = require('hlcraft')

local persist_dir = h.temp_dir('hlcraft-ui-keymap-commands')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, 'HlcraftUiKeymapCommandsNormal', { fg = '#202020' })
engine.set_group('HlcraftUiKeymapCommandsNormal', 'ui-keymap-commands')

local result = { name = 'HlcraftUiKeymapCommandsNormal' }
local instance = {
  state = {
    scene = { name = 'field_editor' },
    detail_index = 1,
    field_editor = { field = 'fg' },
    results = {
      result,
    },
    geometry = {
      editor_rows = {},
    },
  },
  rerender = function() end,
}

h.assert_true(commands.set_color(instance, '#abcdef'), 'set_color command did not handle color field', scope)
h.assert_equal(engine.get(result.name).fg, '#abcdef', 'set_color command did not update color draft', scope)

h.assert_true(commands.toggle_dynamic_color(instance), 'toggle_dynamic_color did not handle color field', scope)
h.assert_true(engine.get(result.name).dynamic.fg ~= nil, 'toggle_dynamic_color did not set dynamic draft', scope)

h.assert_true(commands.adjust_dynamic_color(instance, 1), 'adjust_dynamic_color did not handle dynamic field', scope)
h.assert_equal(engine.get(result.name).dynamic.fg.duration, 2250, 'adjust_dynamic_color did not update duration', scope)

h.assert_true(commands.cycle_dynamic_preset(instance), 'cycle_dynamic_preset did not handle dynamic field', scope)
h.assert_equal(engine.get(result.name).dynamic.fg.preset, 'breath', 'cycle_dynamic_preset did not update preset', scope)

instance.state.field_editor.field = 'blend'
h.assert_true(commands.adjust_blend(instance, 7), 'adjust_blend did not handle blend field', scope)
h.assert_equal(engine.get(result.name).blend, 7, 'adjust_blend did not update blend draft', scope)
h.assert_true(commands.unset_blend(instance), 'unset_blend did not handle blend field', scope)
h.assert_true(engine.get(result.name).blend == nil, 'unset_blend did not clear blend draft', scope)

instance.state.field_editor.field = 'group'
h.assert_true(not commands.toggle_dynamic_color(instance), 'toggle_dynamic_color handled non-color field', scope)
h.assert_true(not commands.adjust_dynamic_color(instance, 1), 'adjust_dynamic_color handled non-dynamic field', scope)

vim.fn.delete(persist_dir, 'rf')
config.setup({})

print('hlcraft ui keymap commands: OK')
