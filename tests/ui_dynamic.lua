local h = require('tests.helpers')
local scope = 'hlcraft ui dynamic'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local dynamic_renderer = require('hlcraft.ui.render.editors.dynamic')
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
h.assert_equal(
  engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset,
  'pulse',
  'toggle did not create pulse preset',
  scope
)

local cycle_ok, cycle_err = editor.cycle_preset(instance, result, 'fg')
h.assert_true(cycle_ok, cycle_err or 'cycle preset failed', scope)
h.assert_equal(
  engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset,
  'breath',
  'cycle did not move to breath preset',
  scope
)

local duration_ok, duration_err = editor.adjust_duration(instance, result, 'fg', 250)
h.assert_true(duration_ok, duration_err or 'duration adjust failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.duration, 2250, 'duration did not adjust', scope)

local loop_ok, loop_err = editor.set_loop(instance, result, 'fg', 'once')
h.assert_true(loop_ok, loop_err or 'loop set failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.loop, 'once', 'loop did not set', scope)

local phase_ok, phase_err = editor.set_phase(instance, result, 'fg', '0.5')
h.assert_true(phase_ok, phase_err or 'phase set failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.phase, 0.5, 'phase did not set', scope)

local raw_ok, raw_err = editor.set_raw_json(
  instance,
  result,
  'fg',
  vim.json.encode({
    version = 1,
    preset = 'manual',
    duration = 1000,
    loop = 'repeat',
    timeline = {
      { at = 0, color = 'base' },
      { at = 1, color = '#ffffff' },
    },
  })
)
h.assert_true(raw_ok, raw_err or 'raw json set failed', scope)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset, 'manual', 'raw json preset did not set', scope)

local bad_schema_ok = editor.set_raw_json(
  instance,
  result,
  'fg',
  vim.json.encode({
    version = 1,
    loop = 'bad',
    timeline = {
      { at = 0, color = 'base' },
    },
  })
)
h.assert_true(not bad_schema_ok, 'invalid dynamic JSON schema was accepted', scope)
h.assert_equal(
  engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset,
  'manual',
  'invalid dynamic JSON schema changed draft',
  scope
)

local bad_raw_ok = editor.set_raw_json(instance, result, 'fg', '{bad json')
h.assert_true(not bad_raw_ok, 'invalid raw json was accepted', scope)
h.assert_equal(
  engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset,
  'manual',
  'invalid raw json changed draft',
  scope
)

h.with_temp_buf(function(render_buf)
  local render_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-dynamic-render-test'),
    state = {
      buf = render_buf,
    },
  }
  local render_geometry = { editor_rows = {} }
  local render_lines = dynamic_renderer.build(
    render_instance,
    render_geometry,
    result,
    'fg',
    80,
    0,
    engine.get('HlcraftUiDynamicNormal').dynamic.fg
  )
  h.assert_true(render_geometry.editor_rows.dynamic_loop ~= nil, 'loop row is not editable', scope)
  h.assert_true(render_geometry.editor_rows.dynamic_phase ~= nil, 'phase row is not editable', scope)
  h.assert_true(render_geometry.editor_rows.dynamic_raw_json ~= nil, 'raw JSON row is not editable', scope)

  local swatch_line = nil
  for index, line in ipairs(render_lines) do
    if line:find('Swatch:', 1, true) then
      swatch_line = index
      break
    end
  end

  h.assert_equal(
    render_instance.state.dynamic_preview_items[1].line,
    swatch_line,
    'dynamic swatch preview did not track its rendered row',
    scope
  )
  h.assert_true(render_geometry.editor_rows.dynamic_swatch == nil, 'dynamic swatch row should not be selectable', scope)
end)

h.with_temp_buf(function(preview_buf)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { 'XXXX' })
  local preview_ns = vim.api.nvim_create_namespace('hlcraft-ui-dynamic-test')
  local preview_instance = {
    ns = preview_ns,
    state = {
      buf = preview_buf,
    },
  }
  local preview_dynamic = {
    version = 1,
    duration = 1000,
    loop = 'once',
    timeline = {
      { at = 0, color = 'base' },
      { at = 1, color = '#ffffff' },
    },
  }
  local preview_id = dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
    now_ms = 500,
  })
  h.assert_equal(preview_id, 1, 'preview item was not registered', scope)
  h.assert_true(dynamic_preview.register(preview_instance, {
    line = 1,
    text = 'XXXX',
    base = '#000000',
    dynamic = {
      version = 1,
      timeline = {},
    },
  }) == nil, 'invalid dynamic preview item was registered', scope)
  dynamic_preview.tick(preview_instance, 0)
  local preview_hl_name = ('HlcraftDynamicPreview_%s_%d'):format(
    tostring(preview_instance.state.dynamic_preview_instance_id),
    preview_id
  )
  local first_preview_hl = vim.api.nvim_get_hl(preview_ns, { name = preview_hl_name })
  h.assert_equal(first_preview_hl.fg, 0x808080, 'fixed preview did not sample requested phase', scope)
  dynamic_preview.tick(preview_instance, 1000)
  local second_preview_hl = vim.api.nvim_get_hl(preview_ns, { name = preview_hl_name })
  h.assert_equal(second_preview_hl.fg, 0x808080, 'fixed preview changed with live time', scope)
  dynamic_preview.clear(preview_instance)
end)

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui dynamic: OK')
