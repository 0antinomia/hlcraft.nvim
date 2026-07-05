local h = require('tests.helpers')
local scope = 'hlcraft ui render editors'

local blend_renderer = require('hlcraft.ui.render.editors.blend')
local color_renderer = require('hlcraft.ui.render.editors.color')
local dynamic_renderer = require('hlcraft.ui.render.editors.dynamic')
local dynamic_model = require('hlcraft.dynamic.model')
local group_renderer = require('hlcraft.ui.render.editors.group')
local ui_state = require('hlcraft.ui.state')

local instance = {
  state = {
    dynamic_preview = ui_state.dynamic_preview(),
  },
}
local result = {
  name = 'HlcraftUiRenderEditorsNormal',
  fg = '#111111',
  resolved_fg = '#111111',
  bg = '#222222',
  resolved_bg = '#222222',
  sp = '#333333',
}

local color_geometry = { editor_rows = {} }
local color_lines = color_renderer.build(color_geometry, result, 'fg', 80)
local color_text = table.concat(color_lines, '\n')
h.assert_true(color_text:find('Adjust  ', 1, true) ~= nil, 'color editor lacks an action section', scope)
h.assert_true(color_text:find('        [b/B] blue', 1, true) ~= nil, 'color editor adjust hints stayed crowded', scope)
h.assert_true(color_text:find('Set     ', 1, true) ~= nil, 'color editor lacks a set section', scope)
h.assert_true(color_text:find('        [d] dynamic', 1, true) ~= nil, 'color editor set hints stayed crowded', scope)
h.assert_true(color_text:find('Global  ', 1, true) ~= nil, 'color editor lacks a global section', scope)
h.assert_true(color_text:find('        [?] help', 1, true) ~= nil, 'color editor global hints stayed crowded', scope)
h.assert_true(not color_text:find('Keys:', 1, true), 'color editor kept crowded Keys hint', scope)
h.assert_true(color_geometry.editor_rows.color_keys == nil, 'color hint row should not be selectable', scope)
local invalid_color_geometry_ok = pcall(color_renderer.build, {}, result, 'fg', 80)
h.assert_true(not invalid_color_geometry_ok, 'color editor accepted missing geometry', scope)
local invalid_color_result_ok = pcall(color_renderer.build, { editor_rows = {} }, {}, 'fg', 80)
h.assert_true(not invalid_color_result_ok, 'color editor accepted missing result', scope)
local invalid_color_field_ok = pcall(color_renderer.build, { editor_rows = {} }, result, '', 80)
h.assert_true(not invalid_color_field_ok, 'color editor accepted empty field', scope)
local invalid_color_width_ok = pcall(color_renderer.build, { editor_rows = {} }, result, 'fg', 0)
h.assert_true(not invalid_color_width_ok, 'color editor accepted invalid width', scope)
local invalid_blend_width_ok = pcall(blend_renderer.build, { editor_rows = {} }, result, 0)
h.assert_true(not invalid_blend_width_ok, 'blend editor accepted invalid width', scope)
local invalid_group_result_ok = pcall(group_renderer.build, { editor_rows = {} }, {}, 80)
h.assert_true(not invalid_group_result_ok, 'group editor accepted missing result', scope)

local dynamic_geometry = { editor_rows = {} }
local dynamic = dynamic_model.normalize_channel({
  version = 1,
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
  },
})
local dynamic_lines = dynamic_renderer.build(instance, dynamic_geometry, result, 'fg', 80, 0, dynamic)
local dynamic_text = table.concat(dynamic_lines, '\n')
h.assert_true(dynamic_geometry.editor_rows.dynamic_loop ~= nil, 'dynamic loop row must stay editable', scope)
h.assert_true(dynamic_geometry.editor_rows.dynamic_phase ~= nil, 'dynamic phase row must stay editable', scope)
h.assert_true(dynamic_text:find('Edit    ', 1, true) ~= nil, 'dynamic editor lacks an edit section', scope)
h.assert_true(dynamic_text:find('Global  ', 1, true) ~= nil, 'dynamic editor lacks a global section', scope)
h.assert_true(dynamic_text:find('Sample 0.50:', 1, true) ~= nil, 'dynamic editor omitted timeline samples', scope)
h.assert_true(not dynamic_text:find('Keys:', 1, true), 'dynamic editor kept crowded Keys hint', scope)
h.assert_true(dynamic_geometry.editor_rows.dynamic_keys == nil, 'dynamic hint row should not be selectable', scope)
h.assert_true(
  dynamic_geometry.editor_rows['dynamic_sample:0.50'] == nil,
  'dynamic sample row should not be selectable',
  scope
)
local invalid_dynamic_instance_ok =
  pcall(dynamic_renderer.build, nil, { editor_rows = {} }, result, 'fg', 80, 0, dynamic)
h.assert_true(not invalid_dynamic_instance_ok, 'dynamic editor accepted missing instance', scope)
local invalid_dynamic_value_ok =
  pcall(dynamic_renderer.build, instance, { editor_rows = {} }, result, 'fg', 80, 0, false)
h.assert_true(not invalid_dynamic_value_ok, 'dynamic editor accepted invalid dynamic value', scope)

print('hlcraft ui render editors: OK')
