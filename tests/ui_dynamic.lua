local h = require('tests.helpers')
local scope = 'hlcraft ui dynamic'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local dynamic_model = require('hlcraft.dynamic.model')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local dynamic_renderer = require('hlcraft.ui.render.editors.dynamic')
local editor = require('hlcraft.ui.editor.dynamic')
local engine = require('hlcraft.engine.service')
local raw_dynamic = require('hlcraft.ui.raw_dynamic')
local ui_state = require('hlcraft.ui.state')

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

local function assert_fails(fn, message)
  h.assert_true(not pcall(fn), message, scope)
end

local toggle_ok, toggle_err = editor.toggle(instance, result, 'fg')
h.assert_true(toggle_ok, toggle_err or 'toggle dynamic failed', scope)
h.assert_equal(
  engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset,
  'pulse',
  'toggle did not create pulse preset',
  scope
)
local clear_toggle_ok, clear_toggle_err = editor.toggle(instance, result, 'fg')
h.assert_true(clear_toggle_ok, clear_toggle_err or 'toggle dynamic clear failed', scope)
h.assert_true(engine.get('HlcraftUiDynamicNormal').dynamic == nil, 'toggle did not clear dynamic field', scope)
local reset_toggle_ok, reset_toggle_err = editor.toggle(instance, result, 'fg')
h.assert_true(reset_toggle_ok, reset_toggle_err or 'toggle dynamic reset failed', scope)
h.assert_equal(
  engine.get('HlcraftUiDynamicNormal').dynamic.fg.preset,
  'pulse',
  'toggle did not recreate pulse preset',
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
local bad_loop_ok, bad_loop_err = editor.set_loop(instance, result, 'fg', 'bad')
h.assert_true(not bad_loop_ok, 'invalid loop set succeeded', scope)
h.assert_true(
  tostring(bad_loop_err):find('Loop must be one of:', 1, true) ~= nil,
  'invalid loop reported wrong error',
  scope
)
h.assert_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg.loop, 'once', 'invalid loop changed draft', scope)

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

local compact_raw_ok, compact_raw_err = editor.set_raw_json(
  instance,
  result,
  'fg',
  vim.json.encode({
    version = 1,
    timeline = {
      { at = 0, color = 'base' },
    },
  })
)
h.assert_true(compact_raw_ok, compact_raw_err or 'compact raw json set failed', scope)
h.assert_equal(
  engine.get('HlcraftUiDynamicNormal').dynamic.fg.duration,
  dynamic_model.default_duration,
  'compact raw json did not normalize duration',
  scope
)
local compact_duration_ok, compact_duration_err = editor.adjust_duration(instance, result, 'fg', 100)
h.assert_true(compact_duration_ok, compact_duration_err or 'compact duration adjust failed', scope)
h.assert_equal(
  engine.get('HlcraftUiDynamicNormal').dynamic.fg.duration,
  dynamic_model.default_duration + 100,
  'duration adjust did not rely on normalized value',
  scope
)
local bad_duration_delta_ok, bad_duration_delta_err = editor.adjust_duration(instance, result, 'fg', 0 / 0)
h.assert_true(not bad_duration_delta_ok, 'duration adjust accepted NaN delta', scope)
h.assert_equal(
  bad_duration_delta_err,
  'Duration adjustment delta must be a finite number',
  'duration adjust NaN error changed',
  scope
)
h.assert_equal(
  engine.get('HlcraftUiDynamicNormal').dynamic.fg.duration,
  dynamic_model.default_duration + 100,
  'duration adjust NaN changed draft',
  scope
)

local before_bad_json = vim.deepcopy(engine.get('HlcraftUiDynamicNormal').dynamic.fg)
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
h.assert_true(
  vim.deep_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg, before_bad_json),
  'invalid dynamic JSON schema changed draft',
  scope
)

local bad_raw_ok = editor.set_raw_json(instance, result, 'fg', '{bad json')
h.assert_true(not bad_raw_ok, 'invalid raw json was accepted', scope)
h.assert_true(
  vim.deep_equal(engine.get('HlcraftUiDynamicNormal').dynamic.fg, before_bad_json),
  'invalid raw json changed draft',
  scope
)

local missing_raw_instance_ok = pcall(raw_dynamic.close, nil)
h.assert_true(not missing_raw_instance_ok, 'raw dynamic close accepted missing instance', scope)
local missing_raw_open_instance_ok = pcall(raw_dynamic.open, nil, result, 'fg')
h.assert_true(not missing_raw_open_instance_ok, 'raw dynamic open accepted missing instance', scope)
local invalid_raw_state_ok = pcall(raw_dynamic.close, {
  state = {
    raw_dynamic = true,
  },
})
h.assert_true(not invalid_raw_state_ok, 'raw dynamic close accepted invalid state schema', scope)
local invalid_raw_field_ok = pcall(raw_dynamic.open, {
  state = {},
}, result, false)
h.assert_true(not invalid_raw_field_ok, 'raw dynamic open accepted invalid field', scope)

h.with_temp_buf(function(render_buf)
  local render_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-dynamic-render-test'),
    state = {
      buf = render_buf,
      dynamic_preview = ui_state.dynamic_preview(),
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
    render_instance.state.dynamic_preview.items[1].line,
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
      dynamic_preview = ui_state.dynamic_preview(),
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
  assert_fails(function()
    dynamic_preview.register(nil, {})
  end, 'dynamic preview accepted missing instance')
  local missing_preview_state_ok = pcall(dynamic_preview.register, {
    ns = preview_ns,
    state = {
      buf = preview_buf,
    },
  }, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  })
  h.assert_true(not missing_preview_state_ok, 'dynamic preview accepted missing state schema', scope)
  assert_fails(function()
    dynamic_preview.register({
      ns = false,
      state = {
        buf = preview_buf,
        dynamic_preview = ui_state.dynamic_preview(),
      },
    }, {
      line = 1,
      col_start = 0,
      col_end = 4,
      text = 'XXXX',
      base = '#000000',
      dynamic = preview_dynamic,
    })
  end, 'dynamic preview accepted invalid namespace')
  h.assert_true(dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = {
      version = 1,
      timeline = {},
    },
  }) == nil, 'invalid dynamic preview item was registered', scope)
  h.assert_true(dynamic_preview.register(preview_instance, {
    line = 0,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  }) == nil, 'invalid preview geometry was registered', scope)
  h.assert_true(dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 4,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  }) == nil, 'invalid preview columns were registered', scope)
  h.assert_true(dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 0.5,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  }) == nil, 'fractional preview column was registered', scope)
  assert_fails(function()
    dynamic_preview.tick(preview_instance, math.huge)
  end, 'dynamic preview accepted infinite tick time')
  dynamic_preview.tick(preview_instance, 0)
  local preview_hl_name = ('HlcraftDynamicPreview_%s_%d'):format(
    tostring(preview_instance.state.dynamic_preview.instance_id),
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
