local h = require('tests.helpers')
local scope = 'hlcraft ui editor rows'

local editor_rows = require('hlcraft.ui.render.editor_rows')

local geometry = { editor_rows = {} }
local lines = {}
local row = editor_rows.append(lines, geometry, 'sample_row', 'Sample')
h.assert_equal(row.line, 1, 'editor row helper returned wrong line', scope)
h.assert_equal(row.key, 'sample_row', 'editor row helper returned wrong key', scope)
h.assert_equal(geometry.editor_rows.sample_row, row, 'editor row helper did not register geometry', scope)
h.assert_equal(lines[1], 'Sample', 'editor row helper did not append line', scope)
local invalid_lines_ok = pcall(editor_rows.append, false, { editor_rows = {} }, 'sample', 'Sample')
h.assert_true(not invalid_lines_ok, 'editor row helper accepted non-table lines', scope)
local non_sequence_lines_ok = pcall(editor_rows.append, { [2] = 'stale' }, { editor_rows = {} }, 'sample', 'Sample')
h.assert_true(not non_sequence_lines_ok, 'editor row helper accepted non-sequence lines', scope)
local invalid_geometry_ok = pcall(editor_rows.append, {}, {}, 'sample', 'Sample')
h.assert_true(not invalid_geometry_ok, 'editor row helper accepted missing row geometry', scope)
local invalid_key_ok = pcall(editor_rows.append, {}, { editor_rows = {} }, '', 'Sample')
h.assert_true(not invalid_key_ok, 'editor row helper accepted empty key', scope)
local invalid_text_ok = pcall(editor_rows.append, {}, { editor_rows = {} }, 'sample', '')
h.assert_true(not invalid_text_ok, 'editor row helper accepted empty text', scope)
local duplicate_row_ok = pcall(editor_rows.append, {}, {
  editor_rows = {
    sample = {
      line = 1,
    },
  },
}, 'sample', 'Sample')
h.assert_true(not duplicate_row_ok, 'editor row helper accepted a duplicate key', scope)

print('hlcraft ui editor rows: OK')
