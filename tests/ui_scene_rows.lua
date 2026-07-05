local h = require('tests.helpers')
local scope = 'hlcraft ui scene rows'

local rows = require('hlcraft.ui.scene.rows')

local function assert_fails(fn, message)
  h.assert_true(not pcall(fn), message, scope)
end

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
assert_fails(function()
  rows.find_by_line(nil, 8)
end, 'row helper accepted nil rows')
assert_fails(function()
  rows.find_by_line({ fg = { line = 7 } }, 0)
end, 'row helper accepted invalid target line')
assert_fails(function()
  rows.find_by_line({ fg = false }, 7)
end, 'row helper accepted non-table row')
assert_fails(function()
  rows.find_by_line({ fg = { line = math.huge } }, math.huge)
end, 'row helper accepted infinite row line')
assert_fails(function()
  rows.cursor_line(nil)
end, 'row cursor lookup accepted missing instance')
assert_fails(function()
  rows.detail_menu_at_cursor({
    state = {},
  })
end, 'detail row lookup accepted missing geometry')
assert_fails(function()
  rows.editor_row_at_cursor({
    state = {
      geometry = {},
    },
  })
end, 'editor row lookup accepted missing geometry')

print('hlcraft ui scene rows: OK')
