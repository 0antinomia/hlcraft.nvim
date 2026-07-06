local h = require('tests.helpers')
local scope = 'hlcraft ui render'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local detail_renderer = require('hlcraft.ui.render.detail')
local dynamic_model = require('hlcraft.dynamic.model')
local engine = require('hlcraft.engine.service')
local field_editor_renderer = require('hlcraft.ui.render.field_editor')
local ui_state = require('hlcraft.ui.state')

local persist_dir = h.temp_dir('hlcraft-ui-render')
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

vim.api.nvim_set_hl(0, 'HlcraftUiRenderNormal', {
  fg = '#111111',
  bg = '#222222',
  sp = '#333333',
})
engine.set_group('HlcraftUiRenderNormal', 'ui-render')

local instance = {
  state = {
    dynamic_preview = ui_state.dynamic_preview(),
  },
  rerender = function() end,
}
local result = {
  name = 'HlcraftUiRenderNormal',
  fg = '#111111',
  resolved_fg = '#111111',
  bg = '#222222',
  resolved_bg = '#222222',
  sp = '#333333',
}

local strict_detail_ok = pcall(detail_renderer.build, { detail_menu = {} }, result, 80)
h.assert_true(not strict_detail_ok, 'detail renderer accepted a build call without instance', scope)
local strict_detail_geometry_ok = pcall(detail_renderer.build, instance, {}, result, 80)
h.assert_true(not strict_detail_geometry_ok, 'detail renderer accepted missing detail geometry', scope)
local strict_detail_result_ok = pcall(detail_renderer.build, instance, { detail_menu = {} }, {}, 80)
h.assert_true(not strict_detail_result_ok, 'detail renderer accepted missing highlight result', scope)
local strict_detail_empty_result_ok, strict_detail_empty_result_err = pcall(
  detail_renderer.build,
  instance,
  { detail_menu = {} },
  { name = '' },
  80,
  0
)
h.assert_true(not strict_detail_empty_result_ok, 'detail renderer accepted empty highlight result name', scope)
h.assert_true(
  tostring(strict_detail_empty_result_err):find('detail renderer requires a highlight result', 1, true) ~= nil,
  'empty detail result bypassed renderer validation',
  scope
)
local strict_detail_offset_ok = pcall(detail_renderer.build, instance, { detail_menu = {} }, result, 80)
h.assert_true(not strict_detail_offset_ok, 'detail renderer accepted missing line offset', scope)
local strict_field_editor_ok = pcall(field_editor_renderer.build, { editor_rows = {} }, result, 'fg', 80)
h.assert_true(not strict_field_editor_ok, 'field editor renderer accepted a build call without instance', scope)
local strict_field_editor_geometry_ok = pcall(field_editor_renderer.build, instance, {}, result, 'fg', 80)
h.assert_true(not strict_field_editor_geometry_ok, 'field editor renderer accepted missing editor geometry', scope)
local strict_field_editor_result_ok = pcall(field_editor_renderer.build, instance, { editor_rows = {} }, {}, 'fg', 80)
h.assert_true(not strict_field_editor_result_ok, 'field editor renderer accepted missing highlight result', scope)
local strict_field_editor_result_name_ok = pcall(
  field_editor_renderer.build,
  instance,
  { editor_rows = {} },
  { name = '' },
  'fg',
  80,
  0
)
h.assert_true(not strict_field_editor_result_name_ok, 'field editor renderer accepted empty result name', scope)
local strict_field_editor_field_ok = pcall(field_editor_renderer.build, instance, { editor_rows = {} }, result, nil, 80)
h.assert_true(not strict_field_editor_field_ok, 'field editor renderer accepted missing field', scope)
local strict_field_editor_empty_field_ok =
  pcall(field_editor_renderer.build, instance, { editor_rows = {} }, result, '', 80, 0)
h.assert_true(not strict_field_editor_empty_field_ok, 'field editor renderer accepted empty field', scope)
local strict_field_editor_offset_ok =
  pcall(field_editor_renderer.build, instance, { editor_rows = {} }, result, 'fg', 80)
h.assert_true(not strict_field_editor_offset_ok, 'field editor renderer accepted missing line offset', scope)
local strict_field_editor_render_state_ok = pcall(field_editor_renderer.render, { state = {} })
h.assert_true(
  not strict_field_editor_render_state_ok,
  'field editor renderer accepted missing field editor state',
  scope
)
local strict_field_editor_render_field_ok = pcall(field_editor_renderer.render, {
  state = {
    field_editor = { field = false },
  },
})
h.assert_true(not strict_field_editor_render_field_ok, 'field editor renderer accepted invalid current field', scope)

local detail_geometry = { detail_menu = {} }
local detail_lines = detail_renderer.build(instance, detail_geometry, result, 80, 0)
local fg_row = detail_geometry.detail_menu.fg
h.assert_true(fg_row.label_start_col ~= nil, 'detail row lacks label highlight start', scope)
h.assert_true(fg_row.label_end_col > fg_row.label_start_col, 'detail row label highlight range is invalid', scope)
h.assert_true(fg_row.value_col > fg_row.label_end_col, 'detail row lacks value highlight start', scope)
local narrow_detail_lines = detail_renderer.build(instance, { detail_menu = {} }, result, 30, 0)
h.assert_true(
  vim.tbl_contains(narrow_detail_lines, '        [s] save  [?] help'),
  'detail renderer did not wrap narrow hints',
  scope
)

local dynamic = dynamic_model.normalize_channel({
  version = 1,
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
  },
})
local dynamic_set_ok, dynamic_set_err = engine.set_dynamic('HlcraftUiRenderNormal', 'fg', dynamic)
h.assert_true(dynamic_set_ok, dynamic_set_err or 'dynamic fixture did not set', scope)
local dynamic_detail_geometry = { detail_menu = {} }
local dynamic_detail_lines = detail_renderer.build(instance, dynamic_detail_geometry, result, 80, 0)
local dynamic_detail_text = table.concat(dynamic_detail_lines, '\n')
h.assert_true(
  dynamic_detail_text:find('custom 1000ms repeat', 1, true) ~= nil,
  'detail dynamic metadata did not use normalized values',
  scope
)
h.with_temp_buf(function(buf)
  local dynamic_detail_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-dynamic-detail-test'),
    state = {
      buf = buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  detail_renderer.build(dynamic_detail_instance, { detail_menu = {} }, result, 80, 0)
  h.assert_equal(
    dynamic_detail_instance.state.dynamic_preview.items[1].context.bg,
    '#222222',
    'detail dynamic preview missed renderer color context',
    scope
  )
end)

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui render: OK')
