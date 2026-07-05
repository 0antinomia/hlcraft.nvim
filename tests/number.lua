local h = require('tests.helpers')
local scope = 'hlcraft number'

local numbers = require('hlcraft.core.number')

h.assert_true(numbers.is_finite(0), 'zero was not finite', scope)
h.assert_true(not numbers.is_finite(0 / 0), 'NaN was finite', scope)
h.assert_true(not numbers.is_finite(math.huge), 'infinity was finite', scope)
h.assert_true(not numbers.is_finite('1'), 'string was finite without conversion', scope)

h.assert_equal(numbers.to_finite('1.5', 0), 1.5, 'numeric string did not convert', scope)
h.assert_equal(numbers.to_finite(0 / 0, 9), 9, 'NaN did not fall back', scope)
h.assert_equal(numbers.to_finite(math.huge, 9), 9, 'infinity did not fall back', scope)
local invalid_to_finite_fallback_ok = pcall(numbers.to_finite, 'bad', math.huge)
h.assert_true(not invalid_to_finite_fallback_ok, 'finite conversion accepted non-finite fallback', scope)

h.assert_equal(numbers.clamp(-1, 0, 10), 0, 'low value did not clamp', scope)
h.assert_equal(numbers.clamp(11, 0, 10), 10, 'high value did not clamp', scope)
h.assert_equal(numbers.clamp(5, 0, 10), 5, 'in-range value changed', scope)
local invalid_clamp_value_ok = pcall(numbers.clamp, 0 / 0, 0, 10)
h.assert_true(not invalid_clamp_value_ok, 'clamp accepted a non-finite value', scope)
local invalid_clamp_min_ok = pcall(numbers.clamp, 1, math.huge, 10)
h.assert_true(not invalid_clamp_min_ok, 'clamp accepted a non-finite minimum', scope)
local invalid_clamp_max_ok = pcall(numbers.clamp, 1, 0, math.huge)
h.assert_true(not invalid_clamp_max_ok, 'clamp accepted a non-finite maximum', scope)
local invalid_clamp_range_ok = pcall(numbers.clamp, 1, 10, 0)
h.assert_true(not invalid_clamp_range_ok, 'clamp accepted an inverted range', scope)
h.assert_equal(numbers.clamp_finite(0 / 0, 0, 10, 3), 3, 'finite clamp did not fall back', scope)
h.assert_equal(numbers.clamp_finite(0 / 0, 0, 10), 0, 'finite clamp did not use zero default', scope)
h.assert_equal(numbers.unit(1.5, 0), 1, 'unit high value did not clamp', scope)
h.assert_equal(numbers.unit(-0.5, 0), 0, 'unit low value did not clamp', scope)
h.assert_equal(numbers.unit(0 / 0, 0.25), 0.25, 'unit NaN did not fall back', scope)
h.assert_equal(numbers.unit(0 / 0), 0, 'unit did not use zero default', scope)
local invalid_fallback_ok = pcall(numbers.clamp_finite, 0 / 0, 0, 10, math.huge)
h.assert_true(not invalid_fallback_ok, 'finite clamp accepted non-finite fallback', scope)

h.assert_true(numbers.is_integer(2), 'integer helper rejected an integer', scope)
h.assert_true(not numbers.is_integer(2.5), 'integer helper accepted a fractional value', scope)
h.assert_true(not numbers.is_integer(math.huge), 'integer helper accepted infinity', scope)
h.assert_true(numbers.is_integer(0, 0), 'integer helper rejected a boundary value', scope)
h.assert_true(not numbers.is_integer(0, 1), 'integer helper ignored its minimum', scope)
h.assert_equal(numbers.assert_positive_integer(2, 'sample value'), 2, 'positive integer assert changed value', scope)
h.assert_equal(
  numbers.assert_non_negative_integer(0, 'sample value'),
  0,
  'non-negative integer assert changed value',
  scope
)
local zero_positive_ok, zero_positive_err = pcall(numbers.assert_positive_integer, 0, 'sample value')
h.assert_true(not zero_positive_ok, 'positive integer assert accepted zero', scope)
h.assert_true(
  tostring(zero_positive_err):find('sample value must be a positive finite integer', 1, true) ~= nil,
  'positive integer assert reported wrong error',
  scope
)
local negative_non_negative_ok, negative_non_negative_err =
  pcall(numbers.assert_non_negative_integer, -1, 'sample value')
h.assert_true(not negative_non_negative_ok, 'non-negative integer assert accepted a negative value', scope)
h.assert_true(
  tostring(negative_non_negative_err):find('sample value must be a non-negative finite integer', 1, true) ~= nil,
  'non-negative integer assert reported wrong error',
  scope
)
local missing_integer_label_ok = pcall(numbers.assert_positive_integer, 1, '')
h.assert_true(not missing_integer_label_ok, 'integer assert accepted an empty label', scope)

print('hlcraft number: OK')
