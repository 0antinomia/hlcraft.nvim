local h = require('tests.helpers')
local scope = 'hlcraft ui input paste plan'

local paste_plan = require('hlcraft.ui.input.paste_plan')

local function assert_plan(actual, expected, message)
  h.assert_equal(actual.key, expected.key, message .. ' key', scope)
  h.assert_equal(actual.append_newline, expected.append_newline == true, message .. ' append_newline', scope)
  h.assert_equal(
    actual.cleanup_trailing_newline,
    expected.cleanup_trailing_newline == true,
    message .. ' cleanup_trailing_newline',
    scope
  )
end

local single = {
  start_row = 3,
  end_row = 3,
  value = 'alpha',
}

local empty = {
  start_row = 3,
  end_row = 3,
  value = '',
}

local multiline = {
  start_row = 3,
  end_row = 5,
  value = 'alpha beta',
}

assert_plan(paste_plan.below(nil, 3, false), { key = 'p' }, 'below outside input should use native paste below')
assert_plan(
  paste_plan.below(single, 3, false),
  { key = 'p', append_newline = true, cleanup_trailing_newline = true },
  'below at single-line input should prepare trailing newline'
)
assert_plan(
  paste_plan.below(empty, 3, false),
  { key = 'P', cleanup_trailing_newline = true },
  'below empty input should paste before placeholder line'
)
assert_plan(
  paste_plan.below(multiline, 4, false),
  { key = 'p' },
  'below inside multiline input should use native paste below'
)
assert_plan(
  paste_plan.below(empty, 3, true),
  { key = 'p', append_newline = true, cleanup_trailing_newline = true },
  'visual below paste should prepare trailing newline'
)

assert_plan(paste_plan.above(nil, 3, false), { key = 'P' }, 'above outside input should use native paste above')
assert_plan(paste_plan.above(single, 3, false), { key = 'P' }, 'above non-empty input should use native paste above')
assert_plan(
  paste_plan.above(empty, 3, false),
  { key = 'P', cleanup_trailing_newline = true },
  'above empty input should clean trailing newline'
)
assert_plan(
  paste_plan.above(multiline, 4, false),
  { key = 'P' },
  'above inside multiline input should use native paste above'
)
assert_plan(
  paste_plan.above(single, 3, true),
  { key = 'P', append_newline = true, cleanup_trailing_newline = true },
  'visual above paste should prepare trailing newline'
)

local invalid_input_ok = pcall(paste_plan.below, false, 3, false)
h.assert_true(not invalid_input_ok, 'paste plan accepted non-table input', scope)
local invalid_start_ok = pcall(paste_plan.below, {
  start_row = -1,
  end_row = 3,
  value = 'alpha',
}, 3, false)
h.assert_true(not invalid_start_ok, 'paste plan accepted invalid start row', scope)
local invalid_end_ok = pcall(paste_plan.below, {
  start_row = 3,
  end_row = 2,
  value = 'alpha',
}, 3, false)
h.assert_true(not invalid_end_ok, 'paste plan accepted invalid end row', scope)
local invalid_value_ok = pcall(paste_plan.below, {
  start_row = 3,
  end_row = 3,
  value = false,
}, 3, false)
h.assert_true(not invalid_value_ok, 'paste plan accepted non-string value', scope)
local invalid_row_ok = pcall(paste_plan.below, single, math.huge, false)
h.assert_true(not invalid_row_ok, 'paste plan accepted invalid cursor row', scope)
local invalid_visual_ok = pcall(paste_plan.above, single, 3, nil)
h.assert_true(not invalid_visual_ok, 'paste plan accepted missing visual flag', scope)

print('hlcraft ui input paste plan: OK')
