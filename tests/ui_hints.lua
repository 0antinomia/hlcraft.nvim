local h = require('tests.helpers')
local scope = 'hlcraft ui hints'

local help_model = require('hlcraft.ui.help_model')
local hints = require('hlcraft.ui.render.hints')

h.assert_equal(
  hints.format({
    { 'Enter', 'open/apply' },
    { 'Tab', 'input' },
    { '?', 'more' },
  }),
  '[Enter] open/apply  [Tab] input  [?] more',
  'compact hint formatter changed unexpectedly',
  scope
)
h.assert_equal(hints.search(), 'Action  [Enter] open/apply  [Tab] input  [?] help', 'search hint is too verbose', scope)
h.assert_true(not hints.search():find('Keys:', 1, true), 'search hint kept the crowded Keys prefix', scope)
h.assert_equal(hints.detail(), 'Action  [Enter] edit/toggle  [s] save  [?] help', 'detail hint is too verbose', scope)
local legacy_options_ok = pcall(hints.section_lines, 'Action', 'search', 2)
h.assert_true(not legacy_options_ok, 'hint sections accepted legacy numeric options', scope)
local keyed_item_ok = pcall(hints.format, {
  { key = 'x', action = 'legacy' },
})
h.assert_true(not keyed_item_ok, 'hint formatter accepted keyed item compatibility shape', scope)
local nil_items_ok = pcall(hints.format, nil)
h.assert_true(not nil_items_ok, 'hint formatter accepted nil items', scope)
local false_options_ok = pcall(hints.section_lines, 'Action', 'search', false)
h.assert_true(not false_options_ok, 'hint sections accepted false options', scope)
local unknown_group_ok = pcall(hints.section_lines, 'Action', 'unknown')
h.assert_true(not unknown_group_ok, 'hint sections accepted unknown groups', scope)

local dynamic_hint_lines = hints.dynamic()
h.assert_equal(dynamic_hint_lines[1], 'Edit    [i] row  [m] preset', 'dynamic edit hint first row changed', scope)
h.assert_equal(
  dynamic_hint_lines[2],
  '        [+/-] time/phase  [e] JSON',
  'dynamic edit hint continuation changed',
  scope
)
h.assert_equal(dynamic_hint_lines[3], '', 'dynamic hint groups should be visually separated', scope)
h.assert_equal(dynamic_hint_lines[4], 'Global  [d] static  [s] save', 'dynamic global hint first row changed', scope)
h.assert_equal(dynamic_hint_lines[5], '        [q] back  [?] help', 'dynamic global hint continuation changed', scope)

local narrow_color_hint_lines = hints.color(20)
h.assert_equal(narrow_color_hint_lines[1], 'Adjust  [r/R] red', 'narrow color hint first row changed', scope)
h.assert_equal(narrow_color_hint_lines[2], '        [g/G] green', 'narrow color hint did not wrap actions', scope)
h.assert_true(vim.tbl_contains(narrow_color_hint_lines, ''), 'narrow color hints lack group spacing', scope)
for _, line in ipairs(narrow_color_hint_lines) do
  h.assert_true(vim.fn.strdisplaywidth(line) <= 20, 'narrow color hint exceeded target width', scope)
end

for _, line in ipairs(hints.dynamic(24)) do
  h.assert_true(vim.fn.strdisplaywidth(line) <= 24, 'narrow dynamic hint exceeded target width', scope)
end

local help_lines = help_model.lines('z')
h.assert_equal(help_lines[1], 'hlcraft help', 'help title changed', scope)
h.assert_true(vim.tbl_contains(help_lines, 'Navigation'), 'help navigation section missing', scope)
h.assert_true(vim.tbl_contains(help_lines, 'Actions'), 'help actions section missing', scope)
h.assert_true(vim.tbl_contains(help_lines, '  [z]  preview result'), 'preview key help line missing', scope)
h.assert_true(
  not vim.tbl_contains(help_model.lines(false), '  [false]  preview result'),
  'disabled preview key was rendered',
  scope
)
h.assert_true(vim.tbl_contains(help_lines, '  [J/K]    next/prev result'), 'search jump help line missing', scope)
h.assert_true(help_model.is_item_line('  [q / Esc] back/close'), 'indented help item line was not detected', scope)
h.assert_true(help_model.is_item_line('[q / Esc] back/close'), 'help item line was not detected', scope)
h.assert_true(not help_model.is_item_line('Navigation'), 'help section was treated as item line', scope)
local numeric_preview_ok = pcall(help_model.lines, 1)
h.assert_true(not numeric_preview_ok, 'help model accepted numeric preview key', scope)
local numeric_line_ok = pcall(help_model.is_item_line, 1)
h.assert_true(not numeric_line_ok, 'help item detector accepted a non-string line', scope)
local original_sections = help_model.sections
help_model.sections = function()
  return {
    {
      title = 'Broken',
    },
  }
end
local invalid_help_items_ok = pcall(help_model.lines)
h.assert_true(not invalid_help_items_ok, 'help model accepted a section without items', scope)
help_model.sections = function()
  return {
    {
      title = 'Broken',
      items = {
        { 1, 'action' },
      },
    },
  }
end
local invalid_help_key_ok = pcall(help_model.lines)
h.assert_true(not invalid_help_key_ok, 'help model accepted a non-string help item key', scope)
help_model.sections = original_sections
for _, line in ipairs(help_lines) do
  h.assert_true(vim.fn.strdisplaywidth(line) <= 38, 'help line exceeded compact width', scope)
end

print('hlcraft ui hints: OK')
