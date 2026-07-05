local h = require('tests.helpers')
local scope = 'hlcraft render util'

local render_util = require('hlcraft.render.util')

h.assert_equal(render_util.truncate('abcdef', 4), 'abc…', 'render truncate lost ellipsis budget', scope)
h.assert_equal(
  render_util.truncate('你好世界', 5),
  '你好…',
  'render truncate split wide text incorrectly',
  scope
)
h.assert_equal(render_util.truncate('abcdef', 0), '', 'render truncate ignored zero width', scope)
h.assert_equal(render_util.pad('abc', 5), 'abc  ', 'render pad did not append display padding', scope)
h.assert_equal(render_util.display_color(nil), ' NONE ', 'nil display color changed', scope)
local invalid_display_color_ok = pcall(render_util.display_color, false)
h.assert_true(not invalid_display_color_ok, 'render color display accepted non-string value', scope)
h.assert_equal(render_util.line_at({ 'first' }, 1, 'test geometry'), 'first', 'render line lookup changed', scope)
h.assert_equal(render_util.line_offset(3, 'test geometry'), 3, 'render line offset lookup changed', scope)
local strict_truncate_text_ok = pcall(render_util.truncate, nil, 4)
h.assert_true(not strict_truncate_text_ok, 'render truncate accepted nil text', scope)
local strict_truncate_width_ok = pcall(render_util.truncate, 'abc', math.huge)
h.assert_true(not strict_truncate_width_ok, 'render truncate accepted non-finite width', scope)
local strict_string_list_ok = pcall(render_util.string_list, { [2] = 'late' }, 'test lines')
h.assert_true(not strict_string_list_ok, 'render string list accepted non-sequence lines', scope)
local sparse_line_lookup_ok = pcall(render_util.line_at, { [2] = 'late' }, 2, 'test geometry')
h.assert_true(not sparse_line_lookup_ok, 'render line lookup accepted sparse lines', scope)
local strict_pad_text_ok = pcall(render_util.pad, 1, 4)
h.assert_true(not strict_pad_text_ok, 'render pad accepted non-string text', scope)
local strict_pad_width_ok = pcall(render_util.pad, 'abc', 1.5)
h.assert_true(not strict_pad_width_ok, 'render pad accepted fractional width', scope)
local missing_render_line_ok = pcall(render_util.line_at, { 'first' }, 2, 'test geometry')
h.assert_true(not missing_render_line_ok, 'render line lookup accepted missing line', scope)
local invalid_render_line_nr_ok = pcall(render_util.line_at, { 'first' }, 0, 'test geometry')
h.assert_true(not invalid_render_line_nr_ok, 'render line lookup accepted invalid line number', scope)
local invalid_render_offset_ok = pcall(render_util.line_offset, -1, 'test geometry')
h.assert_true(not invalid_render_offset_ok, 'render line offset accepted a negative value', scope)

print('hlcraft render util: OK')
