local h = require('tests.helpers')
local scope = 'hlcraft ui render'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local color_renderer = require('hlcraft.ui.render.editors.color')
local decorations = require('hlcraft.ui.render.decorations')
local detail_renderer = require('hlcraft.ui.render.detail')
local dynamic_renderer = require('hlcraft.ui.render.editors.dynamic')
local dynamic_model = require('hlcraft.dynamic.model')
local engine = require('hlcraft.engine.service')
local editor_layout = require('hlcraft.ui.render.editor_layout')
local editor_rows = require('hlcraft.ui.render.editor_rows')
local field_editor_renderer = require('hlcraft.ui.render.field_editor')
local render_buffer = require('hlcraft.ui.render.buffer')
local render_util = require('hlcraft.render.util')
local theme = require('hlcraft.ui.theme')
local ui_state = require('hlcraft.ui.state')

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

local editor_geometry = { editor_rows = {} }
local editor_lines = {}
local editor_row = editor_rows.append(editor_lines, editor_geometry, 'sample_row', 'Sample')
h.assert_equal(editor_row.line, 1, 'editor row helper returned wrong line', scope)
h.assert_equal(editor_row.key, 'sample_row', 'editor row helper returned wrong key', scope)
h.assert_equal(editor_geometry.editor_rows.sample_row, editor_row, 'editor row helper did not register geometry', scope)
h.assert_equal(editor_lines[1], 'Sample', 'editor row helper did not append line', scope)
local invalid_input_extra_ok = pcall(render_buffer.new_input_field, 'name', 'name', 1, false)
h.assert_true(not invalid_input_extra_ok, 'input field helper accepted non-table extra options', scope)
h.assert_equal(render_util.truncate('abcdef', 4), 'abc…', 'render truncate lost ellipsis budget', scope)
h.assert_equal(
  render_util.truncate('你好世界', 5),
  '你好…',
  'render truncate split wide text incorrectly',
  scope
)
h.assert_equal(render_util.truncate('abcdef', 0), '', 'render truncate ignored zero width', scope)
h.assert_equal(render_util.pad('abc', 5), 'abc  ', 'render pad did not append display padding', scope)
local strict_truncate_text_ok = pcall(render_util.truncate, nil, 4)
h.assert_true(not strict_truncate_text_ok, 'render truncate accepted nil text', scope)
local strict_truncate_width_ok = pcall(render_util.truncate, 'abc', math.huge)
h.assert_true(not strict_truncate_width_ok, 'render truncate accepted non-finite width', scope)
local strict_pad_text_ok = pcall(render_util.pad, 1, 4)
h.assert_true(not strict_pad_text_ok, 'render pad accepted non-string text', scope)
local strict_pad_width_ok = pcall(render_util.pad, 'abc', 1.5)
h.assert_true(not strict_pad_width_ok, 'render pad accepted fractional width', scope)
local layout_lines = editor_layout.finish({ 'Current: abcdefghijklmnop' }, 12, { 'Action  [x] go' })
h.assert_equal(layout_lines[2], '', 'editor layout did not separate hints from content', scope)
h.assert_true(vim.fn.strdisplaywidth(layout_lines[1]) <= 12, 'editor layout did not truncate content lines', scope)
h.assert_true(vim.fn.strdisplaywidth(layout_lines[3]) <= 12, 'editor layout did not truncate hint lines', scope)
local nil_find_line_ok = pcall(decorations.find_text_start, nil, 'x', 0)
h.assert_true(not nil_find_line_ok, 'text finder accepted nil line', scope)
local nil_find_text_ok = pcall(decorations.find_text_start, 'x', nil, 0)
h.assert_true(not nil_find_text_ok, 'text finder accepted nil text', scope)
local invalid_find_start_ok = pcall(decorations.find_text_start, 'x', 'x', 0.5)
h.assert_true(not invalid_find_start_ok, 'text finder accepted fractional start column', scope)
local invalid_header_opts_ok = pcall(decorations.set_input_header, {}, {}, 'Label', false)
h.assert_true(not invalid_header_opts_ok, 'input header accepted non-table options', scope)

local strict_detail_ok = pcall(detail_renderer.build, { detail_menu = {} }, result, 80)
h.assert_true(not strict_detail_ok, 'detail renderer accepted a build call without instance', scope)
local strict_field_editor_ok = pcall(field_editor_renderer.build, { editor_rows = {} }, result, 'fg', 80)
h.assert_true(not strict_field_editor_ok, 'field editor renderer accepted a build call without instance', scope)

local detail_geometry = { detail_menu = {} }
local detail_lines = detail_renderer.build(instance, detail_geometry, result, 80, 0)
local fg_row = detail_geometry.detail_menu.fg
h.assert_true(fg_row.label_start_col ~= nil, 'detail row lacks label highlight start', scope)
h.assert_true(fg_row.label_end_col > fg_row.label_start_col, 'detail row label highlight range is invalid', scope)
h.assert_true(fg_row.value_col > fg_row.label_end_col, 'detail row lacks value highlight start', scope)
h.with_temp_buf(function(buf)
  local detail_ns = vim.api.nvim_create_namespace('hlcraft-ui-render-detail-test')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, detail_lines)
  decorations.apply_detail_menu_highlights({
    ns = detail_ns,
    state = {
      buf = buf,
    },
  }, detail_geometry.detail_menu, false)
  local marks = vim.api.nvim_buf_get_extmarks(buf, detail_ns, 0, -1, { details = true })
  h.assert_true(#marks > 0, 'detail menu highlights were not applied', scope)
end)
h.with_temp_buf(function(buf)
  local invalid_detail_menu_ok = pcall(decorations.apply_detail_menu_highlights, {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-invalid-detail-menu-test'),
    state = {
      buf = buf,
    },
  }, nil, false)
  h.assert_true(not invalid_detail_menu_ok, 'detail menu highlighter accepted nil geometry', scope)
end)

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
  theme.groups.value,
  theme.groups.key,
  theme.groups.title,
}) do
  h.assert_true(type(group_name) == 'string' and group_name ~= '', 'missing visual hierarchy group', scope)
  local applied = vim.api.nvim_get_hl(ns, { name = group_name })
  h.assert_true(applied.fg ~= nil, ('theme group %s has no foreground'):format(group_name), scope)
end
local hint_hl = vim.api.nvim_get_hl(ns, { name = theme.groups.hint })
local action_hl = vim.api.nvim_get_hl(ns, { name = theme.groups.hint_action })
h.assert_true(action_hl.fg ~= hint_hl.fg, 'hint actions should contrast with muted hint text', scope)

local color_geometry = { editor_rows = {} }
local color_lines = color_renderer.build(instance, color_geometry, result, 'fg', 80, 0)
local color_text = table.concat(color_lines, '\n')
h.assert_true(color_text:find('Adjust  ', 1, true) ~= nil, 'color editor lacks an action section', scope)
h.assert_true(color_text:find('        [b/B] blue', 1, true) ~= nil, 'color editor adjust hints stayed crowded', scope)
h.assert_true(color_text:find('Set     ', 1, true) ~= nil, 'color editor lacks a set section', scope)
h.assert_true(color_text:find('        [d] dynamic', 1, true) ~= nil, 'color editor set hints stayed crowded', scope)
h.assert_true(color_text:find('Global  ', 1, true) ~= nil, 'color editor lacks a global section', scope)
h.assert_true(color_text:find('        [?] help', 1, true) ~= nil, 'color editor global hints stayed crowded', scope)
h.assert_true(not color_text:find('Keys:', 1, true), 'color editor kept crowded Keys hint', scope)
h.assert_true(color_geometry.editor_rows.color_keys == nil, 'color hint row should not be selectable', scope)

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
h.assert_true(not dynamic_text:find('Keys:', 1, true), 'dynamic editor kept crowded Keys hint', scope)
h.assert_true(dynamic_geometry.editor_rows.dynamic_keys == nil, 'dynamic hint row should not be selectable', scope)

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

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui render: OK')
