local h = require('tests.helpers')
local scope = 'hlcraft ui render'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local color_renderer = require('hlcraft.ui.render.editors.color')
local decorations = require('hlcraft.ui.render.decorations')
local detail_info = require('hlcraft.ui.detail')
local detail_renderer = require('hlcraft.ui.render.detail')
local dynamic_renderer = require('hlcraft.ui.render.editors.dynamic')
local engine = require('hlcraft.engine.service')
local editor_rows = require('hlcraft.ui.render.editor_rows')
local field_editor_renderer = require('hlcraft.ui.render.field_editor')
local help_model = require('hlcraft.ui.help_model')
local hints = require('hlcraft.ui.render.hints')
local theme = require('hlcraft.ui.theme')

local persist_dir = h.temp_dir('hlcraft-ui-render')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, 'HlcraftUiRenderNormal', {
  fg = '#111111',
  bg = '#222222',
  sp = '#333333',
})
engine.set_group('HlcraftUiRenderNormal', 'ui-render')

local instance = {
  state = {},
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

h.assert_equal(
  hints.format({
    { 'Enter', 'open/apply' },
    { 'Tab', 'input' },
    { '?', 'more' },
  }),
  'Enter open/apply  |  Tab input  |  ? more',
  'compact hint formatter changed unexpectedly',
  scope
)
h.assert_equal(hints.search(), 'Action  Enter open/apply  |  Tab input  |  ? help', 'search hint is too verbose', scope)
h.assert_true(not hints.search():find('Keys:', 1, true), 'search hint kept the crowded Keys prefix', scope)
h.assert_equal(hints.detail(), 'Action  Enter edit/toggle  |  s save  |  ? help', 'detail hint is too verbose', scope)

local dynamic_hint_lines = hints.dynamic()
h.assert_equal(dynamic_hint_lines[1], 'Edit    i row  |  m preset', 'dynamic edit hint first row changed', scope)
h.assert_equal(
  dynamic_hint_lines[2],
  '        +/- time/phase  |  e JSON',
  'dynamic edit hint continuation changed',
  scope
)
h.assert_equal(dynamic_hint_lines[3], 'Global  d static  |  s save', 'dynamic global hint first row changed', scope)
h.assert_equal(dynamic_hint_lines[4], '        q back  |  ? help', 'dynamic global hint continuation changed', scope)

local help_lines = help_model.lines('z')
h.assert_equal(help_lines[1], 'hlcraft help', 'help title changed', scope)
h.assert_true(vim.tbl_contains(help_lines, 'Global'), 'help global section missing', scope)
h.assert_true(vim.tbl_contains(help_lines, 'z        flash current result'), 'preview key help line missing', scope)
h.assert_true(help_model.is_item_line('q / Esc  back or close'), 'help item line was not detected', scope)
h.assert_true(not help_model.is_item_line('Global'), 'help section was treated as item line', scope)

local editor_geometry = { editor_rows = {} }
local editor_lines = {}
local editor_row = editor_rows.append(editor_lines, editor_geometry, 'sample_row', 'Sample')
h.assert_equal(editor_row.line, 1, 'editor row helper returned wrong line', scope)
h.assert_equal(editor_row.key, 'sample_row', 'editor row helper returned wrong key', scope)
h.assert_equal(editor_geometry.editor_rows.sample_row, editor_row, 'editor row helper did not register geometry', scope)
h.assert_equal(editor_lines[1], 'Sample', 'editor row helper did not append line', scope)

local strict_detail_ok = pcall(detail_renderer.build, { detail_menu = {} }, result, 80)
h.assert_true(not strict_detail_ok, 'detail renderer accepted a build call without instance', scope)
local strict_field_editor_ok = pcall(field_editor_renderer.build, { editor_rows = {} }, result, 'fg', 80)
h.assert_true(not strict_field_editor_ok, 'field editor renderer accepted a build call without instance', scope)

local top_help = ''
for _, chunk in ipairs(decorations.help_virt_line()) do
  top_help = top_help .. chunk[1]
end
h.assert_true(top_help:find('? help', 1, true) ~= nil, 'top help line should keep help discovery', scope)
h.assert_true(top_help:find('Enter', 1, true) == nil, 'top help line should not repeat scene actions', scope)
h.assert_true(top_help:find('Tab', 1, true) == nil, 'top help line should not repeat input navigation', scope)

local ns = vim.api.nvim_create_namespace('hlcraft-ui-render-test')
theme.apply(ns)
for _, group_name in ipairs({
  theme.groups.section,
  theme.groups.hint,
  theme.groups.hint_action,
  theme.groups.hint_separator,
  theme.groups.value,
  theme.groups.key,
  theme.groups.title,
}) do
  h.assert_true(type(group_name) == 'string' and group_name ~= '', 'missing visual hierarchy group', scope)
  local applied = vim.api.nvim_get_hl(ns, { name = group_name })
  h.assert_true(applied.fg ~= nil, ('theme group %s has no foreground'):format(group_name), scope)
end

local detail_info_lines = detail_info.build_virt_lines(result, function()
  return theme.groups.value
end, 80)
h.assert_equal(detail_info_lines[2][1][2], theme.groups.section, 'detail info label lacks contrast', scope)
h.assert_equal(detail_info_lines[2][2][2], theme.groups.title, 'detail info name lacks title contrast', scope)
h.assert_equal(detail_info_lines[3][1][2], theme.groups.section, 'detail color label lacks contrast', scope)
h.assert_equal(detail_info_lines[4][3][2], theme.groups.muted, 'detail attr metadata lacks muted contrast', scope)

local color_geometry = { editor_rows = {} }
local color_lines = color_renderer.build(instance, color_geometry, result, 'fg', 80, 0)
local color_text = table.concat(color_lines, '\n')
h.assert_true(color_text:find('Adjust  ', 1, true) ~= nil, 'color editor lacks an action section', scope)
h.assert_true(color_text:find('Set     ', 1, true) ~= nil, 'color editor lacks a set section', scope)
h.assert_true(color_text:find('Global  ', 1, true) ~= nil, 'color editor lacks a global section', scope)
h.assert_true(not color_text:find('Keys:', 1, true), 'color editor kept crowded Keys hint', scope)
h.assert_true(color_geometry.editor_rows.color_keys == nil, 'color hint row should not be selectable', scope)

local dynamic_geometry = { editor_rows = {} }
local dynamic = {
  version = 1,
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
  },
}
local dynamic_lines = dynamic_renderer.build(instance, dynamic_geometry, result, 'fg', 80, 0, dynamic)
local dynamic_text = table.concat(dynamic_lines, '\n')
h.assert_true(dynamic_geometry.editor_rows.dynamic_loop ~= nil, 'dynamic loop row must stay editable', scope)
h.assert_true(dynamic_geometry.editor_rows.dynamic_phase ~= nil, 'dynamic phase row must stay editable', scope)
h.assert_true(dynamic_text:find('Edit    ', 1, true) ~= nil, 'dynamic editor lacks an edit section', scope)
h.assert_true(dynamic_text:find('Global  ', 1, true) ~= nil, 'dynamic editor lacks a global section', scope)
h.assert_true(not dynamic_text:find('Keys:', 1, true), 'dynamic editor kept crowded Keys hint', scope)
h.assert_true(dynamic_geometry.editor_rows.dynamic_keys == nil, 'dynamic hint row should not be selectable', scope)

vim.fn.delete(persist_dir, 'rf')
config.setup({})

print('hlcraft ui render: OK')
