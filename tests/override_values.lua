local h = require('tests.helpers')
local scope = 'hlcraft override values'

local override_values = require('hlcraft.core.override_values')

h.assert_true(override_values.is_unset(nil), 'nil was not treated as unset', scope)
h.assert_true(override_values.is_unset(vim.NIL), 'vim.NIL was not treated as unset', scope)
h.assert_true(override_values.is_unset(''), 'blank string was not treated as unset', scope)
h.assert_equal(override_values.entry_value(vim.NIL), nil, 'vim.NIL did not become nil entry value', scope)
h.assert_equal(override_values.entry_value('#ffffff'), '#ffffff', 'entry value changed unexpectedly', scope)

local color_value, color_err = override_values.normalize_color('#ABCDEF')
h.assert_equal(color_value, '#abcdef', color_err or 'color did not normalize', scope)
h.assert_equal(
  select(1, override_values.normalize_color('')),
  vim.NIL,
  'unset color did not normalize to sentinel',
  scope
)
h.assert_true(select(1, override_values.normalize_color(123)) == nil, 'numeric color normalized unexpectedly', scope)

local blend_value, blend_err = override_values.normalize_blend('42.9')
h.assert_equal(blend_value, 42, blend_err or 'blend did not normalize', scope)
h.assert_equal(
  select(2, override_values.normalize_blend('bad')),
  'Blend override must be a number or empty',
  'blend error changed',
  scope
)
h.assert_equal(
  select(2, override_values.normalize_blend(0 / 0)),
  'Blend override must be a number or empty',
  'NaN blend error changed',
  scope
)

h.assert_equal(select(1, override_values.normalize_style('bold', true)), true, 'style true did not normalize', scope)
h.assert_equal(
  select(1, override_values.normalize_style('bold', nil)),
  vim.NIL,
  'nil style did not normalize to sentinel',
  scope
)
h.assert_equal(
  select(2, override_values.normalize_style('bold', 'yes')),
  'Style override bold must be boolean or nil',
  'style error changed',
  scope
)
h.assert_equal(
  select(1, override_values.normalize_field('fg', '#ABCDEF')),
  '#abcdef',
  'field color did not normalize',
  scope
)
h.assert_equal(select(1, override_values.normalize_field('bold', true)), true, 'field style did not normalize', scope)
h.assert_equal(select(1, override_values.normalize_field('blend', '42.9')), 42, 'field blend did not normalize', scope)
h.assert_equal(
  select(2, override_values.normalize_field('unknown', true)),
  'Unsupported override key: unknown',
  'unknown field error changed',
  scope
)

local dynamic_value, dynamic_err = override_values.normalize_dynamic_channel('fg', {
  version = 1,
  timeline = {
    { at = 0, color = 'base' },
  },
})
h.assert_true(dynamic_value ~= nil, dynamic_err or 'dynamic channel did not normalize', scope)
h.assert_equal(
  select(1, override_values.normalize_dynamic_channel('fg', vim.NIL)),
  vim.NIL,
  'unset dynamic did not normalize',
  scope
)

print('hlcraft override values: OK')
