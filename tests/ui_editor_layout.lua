local h = require('tests.helpers')
local scope = 'hlcraft ui editor layout'

local editor_layout = require('hlcraft.ui.render.editor_layout')

local layout_lines = editor_layout.finish({ 'Current: abcdefghijklmnop' }, 12, { 'Action  [x] go' })
h.assert_equal(layout_lines[2], '', 'editor layout did not separate hints from content', scope)
h.assert_true(vim.fn.strdisplaywidth(layout_lines[1]) <= 12, 'editor layout did not truncate content lines', scope)
h.assert_true(vim.fn.strdisplaywidth(layout_lines[3]) <= 12, 'editor layout did not truncate hint lines', scope)
local invalid_lines_ok = pcall(editor_layout.finish, false, 12, {})
h.assert_true(not invalid_lines_ok, 'editor layout accepted non-table lines', scope)
local invalid_width_ok = pcall(editor_layout.finish, {}, math.huge, {})
h.assert_true(not invalid_width_ok, 'editor layout accepted non-finite width', scope)
local invalid_hints_ok = pcall(editor_layout.finish, {}, 12, { false })
h.assert_true(not invalid_hints_ok, 'editor layout accepted non-string hint line', scope)

print('hlcraft ui editor layout: OK')
