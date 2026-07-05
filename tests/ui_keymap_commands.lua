local h = require('tests.helpers')
local scope = 'hlcraft ui keymap commands'

local commands = require('hlcraft.ui.keymap_commands')
local config = require('hlcraft.config')
local engine = require('hlcraft.engine.service')
local hlcraft = require('hlcraft')
local ui_state = require('hlcraft.ui.state')

local persist_dir = h.temp_dir('hlcraft-ui-keymap-commands')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

local assert_fails = h.scoped_assert_fails(scope)

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

h.with_notify_stub(function()
  h.assert_true(
    not commands.set_color(instance, 'bad-color'),
    'set_color command reported invalid color success',
    scope
  )
end)
h.assert_equal(engine.get(result.name).fg, '#abcdef', 'invalid set_color command changed color draft', scope)

h.assert_true(commands.toggle_dynamic_color(instance), 'toggle_dynamic_color did not handle color field', scope)
h.assert_true(engine.get(result.name).dynamic.fg ~= nil, 'toggle_dynamic_color did not set dynamic draft', scope)

h.assert_true(commands.adjust_dynamic_color(instance, 1), 'adjust_dynamic_color did not handle dynamic field', scope)
h.assert_equal(engine.get(result.name).dynamic.fg.duration, 2250, 'adjust_dynamic_color did not update duration', scope)
assert_fails(function()
  commands.adjust_dynamic_color(instance, 0 / 0)
end, 'adjust_dynamic_color accepted NaN delta')
h.assert_equal(
  engine.get(result.name).dynamic.fg.duration,
  2250,
  'adjust_dynamic_color NaN delta changed duration',
  scope
)

h.assert_true(commands.cycle_dynamic_preset(instance), 'cycle_dynamic_preset did not handle dynamic field', scope)
h.assert_equal(engine.get(result.name).dynamic.fg.preset, 'breath', 'cycle_dynamic_preset did not update preset', scope)

local original_run_action = commands.run_action
commands.run_action = function()
  return false
end
h.assert_true(
  not commands.input_current_editor_field(instance),
  'dynamic input command ignored raw JSON action failure',
  scope
)
commands.run_action = original_run_action

h.with_temp_buf(function(phase_buf)
  instance.state.buf = phase_buf
  instance.state.geometry.editor_rows.dynamic_phase = { line = 1, key = 'dynamic_phase' }
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  assert_fails(function()
    commands.adjust_dynamic_color(instance, 0 / 0)
  end, 'phase row dynamic adjustment accepted NaN delta')
  h.assert_equal(engine.get(result.name).dynamic.fg.phase, 0, 'phase row NaN delta changed phase', scope)
end, { current = true })
instance.state.buf = nil
instance.state.geometry.editor_rows = {}

instance.state.field_editor.field = 'blend'
h.assert_true(commands.adjust_blend(instance, 7), 'adjust_blend did not handle blend field', scope)
h.assert_equal(engine.get(result.name).blend, 7, 'adjust_blend did not update blend draft', scope)
h.assert_true(commands.unset_blend(instance), 'unset_blend did not handle blend field', scope)
h.assert_true(engine.get(result.name).blend == nil, 'unset_blend did not clear blend draft', scope)

instance.state.field_editor.field = 'group'
h.assert_true(not commands.toggle_dynamic_color(instance), 'toggle_dynamic_color handled non-color field', scope)
h.assert_true(not commands.adjust_dynamic_color(instance, 1), 'adjust_dynamic_color handled non-dynamic field', scope)
assert_fails(function()
  commands.run_action(instance, '')
end, 'keymap command accepted empty action')
assert_fails(function()
  commands.run_search_action(instance, '')
end, 'keymap command accepted empty search action')
assert_fails(function()
  commands.feed_normal_key(instance, '')
end, 'keymap command accepted empty normal key')
assert_fails(function()
  commands.adjust_color(instance, '', 1, nil)
end, 'keymap command accepted empty color channel')
assert_fails(function()
  commands.adjust_color(instance, 'r', math.huge, nil)
end, 'keymap command accepted infinite color delta')
assert_fails(function()
  commands.set_color(instance, false, nil)
end, 'keymap command accepted non-string color value')
assert_fails(function()
  commands.adjust_blend(instance, 0 / 0, nil)
end, 'keymap command accepted NaN blend delta')
assert_fails(function()
  commands.jump_to_input_at_cursor(instance, nil)
end, 'keymap command accepted missing insert flag')

h.with_temp_buf(function(buf)
  local previous_buf = instance.state.buf
  local previous_extmarks = instance.state.extmark_ids
  local previous_geometry = instance.state.geometry
  local previous_last_win = instance.state.last_workspace_win
  local previous_ns = instance.ns

  instance.ns = vim.api.nvim_create_namespace('hlcraft-ui-keymap-commands-input-test')
  instance.state.buf = buf
  instance.state.extmark_ids = {}
  instance.state.geometry = ui_state.geometry()
  instance.state.last_workspace_win = vim.api.nvim_get_current_win()
  instance.state.geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'alpha', 'beta', 'gamma', 'after' })
  instance.state.extmark_ids['name:start'] = vim.api.nvim_buf_set_extmark(buf, instance.ns, 0, 0, {
    right_gravity = false,
  })
  instance.state.extmark_ids['name:end'] = vim.api.nvim_buf_set_extmark(buf, instance.ns, 3, 0, {
    right_gravity = false,
  })

  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  h.assert_true(
    commands.jump_to_input_at_cursor(instance, false),
    'jump_to_input_at_cursor did not handle multiline input interior',
    scope
  )
  h.assert_equal(
    vim.api.nvim_win_get_cursor(0)[1],
    1,
    'jump_to_input_at_cursor did not jump to tracked input start',
    scope
  )

  instance.state.buf = previous_buf
  instance.state.extmark_ids = previous_extmarks
  instance.state.geometry = previous_geometry
  instance.state.last_workspace_win = previous_last_win
  instance.ns = previous_ns
end, { current = true })

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui keymap commands: OK')
