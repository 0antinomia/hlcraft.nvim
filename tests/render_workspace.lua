local h = require('tests.helpers')
local scope = 'hlcraft render workspace'

local list = require('hlcraft.ui.render.list')
local detail_menu = require('hlcraft.ui.render.detail_menu')
local field_editor = require('hlcraft.ui.render.field_editor')

local list_lines, selectable = list.build({
  state = {
    results = {
      { name = 'Normal', fg = '#111111', bg = 'NONE', sp = 'NONE' },
    },
  },
}, 80)
h.assert_true(list_lines[1]:find('NAME') ~= nil, 'list header did not render', scope)
h.assert_equal(selectable[3], 1, 'list selectable row was not registered', scope)

h.assert_equal(detail_menu.display_text(nil), 'unset', 'nil detail value display is wrong', scope)
h.assert_equal(detail_menu.display_text(true), 'true', 'true detail value display is wrong', scope)
h.assert_equal(detail_menu.display_text(false), 'false', 'false detail value display is wrong', scope)

local result = {
  name = 'HlcraftRenderNormal',
  fg = '#111111',
  bg = 'NONE',
  sp = 'NONE',
  resolved_fg = '#111111',
  resolved_bg = 'NONE',
}
local menu_geometry = {
  detail_menu = {},
}
local menu_lines = detail_menu.build(menu_geometry, result, 80)
h.assert_true(menu_lines[1]:find('Detail fields') ~= nil, 'detail menu title did not render', scope)
h.assert_true(menu_geometry.detail_menu.group ~= nil, 'detail group row was not registered', scope)

local editor_geometry = {
  editor_rows = {},
}
local blend_lines = field_editor.build(editor_geometry, result, 'blend', 80)
h.assert_true(blend_lines[1]:find('Blend editor') ~= nil, 'blend editor did not render', scope)
h.assert_true(editor_geometry.editor_rows.blend_keys ~= nil, 'blend editor key row was not registered', scope)

local dynamic_result = {
  name = 'HlcraftRenderDynamic',
  fg = '#111111',
  bg = 'NONE',
  sp = 'NONE',
  resolved_fg = '#111111',
  resolved_bg = 'NONE',
}

local overrides = require('hlcraft.overrides')
local dynamic_group_ok, dynamic_group_err = overrides.set_group('HlcraftRenderDynamic', 'render')
h.assert_true(dynamic_group_ok, dynamic_group_err or 'failed to set render dynamic group', scope)
local dynamic_set_ok, dynamic_set_err = overrides.set_dynamic('HlcraftRenderDynamic', 'fg', {
  mode = 'rgb',
  speed = 1500,
})
h.assert_true(dynamic_set_ok, dynamic_set_err or 'failed to set render dynamic fg', scope)

local dynamic_geometry = {
  detail_menu = {},
}
local dynamic_menu_lines = detail_menu.build(dynamic_geometry, dynamic_result, 80)
h.assert_true(
  table.concat(dynamic_menu_lines, '\n'):find('dynamic:rgb 1500ms', 1, true) ~= nil,
  'detail menu did not render dynamic color state',
  scope
)

local dynamic_editor_geometry = {
  editor_rows = {},
}
local dynamic_editor_lines = field_editor.build(dynamic_editor_geometry, dynamic_result, 'fg', 80)
local dynamic_editor_text = table.concat(dynamic_editor_lines, '\n')
h.assert_true(dynamic_editor_text:find('Mode: dynamic', 1, true) ~= nil, 'dynamic editor mode missing', scope)
h.assert_true(dynamic_editor_text:find('Effect: rgb', 1, true) ~= nil, 'dynamic editor effect missing', scope)
h.assert_true(dynamic_editor_text:find('Speed: 1500ms', 1, true) ~= nil, 'dynamic editor speed missing', scope)
h.assert_true(dynamic_editor_geometry.editor_rows.dynamic_keys ~= nil, 'dynamic editor keys row missing', scope)

print('hlcraft render workspace: OK')
