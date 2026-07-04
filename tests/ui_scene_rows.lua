local h = require('tests.helpers')
local scope = 'hlcraft ui scene rows'

local rows = require('hlcraft.ui.scene.rows')

local row_map = {
  fg = {
    line = 7,
    kind = 'color',
  },
  bg = {
    line = 9,
    key = 'explicit',
    kind = 'color',
  },
}

local result = rows.find_by_line(row_map, 7)
h.assert_true(result ~= nil, 'row was not found by line', scope)
h.assert_equal(result.key, 'fg', 'row helper did not backfill key from table key', scope)
h.assert_true(row_map.fg.key == nil, 'row helper mutated the geometry row', scope)

local explicit = rows.find_by_line({
  bg = {
    line = 9,
    key = 'explicit',
  },
}, 9)
h.assert_equal(explicit.key, 'explicit', 'row helper overwrote explicit row key', scope)
h.assert_true(rows.find_by_line({ fg = { line = 7 } }, 8) == nil, 'row helper returned a non-matching row', scope)
h.assert_true(rows.find_by_line({ fg = { line = 7 } }, nil) == nil, 'row helper did not handle nil line', scope)
local nil_rows_ok = pcall(rows.find_by_line, nil, 8)
h.assert_true(not nil_rows_ok, 'row helper accepted nil rows', scope)

print('hlcraft ui scene rows: OK')
