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

print('hlcraft render workspace: OK')
