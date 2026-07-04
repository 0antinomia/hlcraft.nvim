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

h.assert_equal(numbers.clamp(-1, 0, 10), 0, 'low value did not clamp', scope)
h.assert_equal(numbers.clamp(11, 0, 10), 10, 'high value did not clamp', scope)
h.assert_equal(numbers.clamp(5, 0, 10), 5, 'in-range value changed', scope)
h.assert_equal(numbers.clamp_finite(0 / 0, 0, 10, 3), 3, 'finite clamp did not fall back', scope)
h.assert_equal(numbers.clamp_finite(0 / 0, 0, 10), 0, 'finite clamp did not use zero default', scope)
h.assert_equal(numbers.unit(1.5, 0), 1, 'unit high value did not clamp', scope)
h.assert_equal(numbers.unit(-0.5, 0), 0, 'unit low value did not clamp', scope)
h.assert_equal(numbers.unit(0 / 0, 0.25), 0.25, 'unit NaN did not fall back', scope)
h.assert_equal(numbers.unit(0 / 0), 0, 'unit did not use zero default', scope)
local invalid_fallback_ok = pcall(numbers.clamp_finite, 0 / 0, 0, 10, math.huge)
h.assert_true(not invalid_fallback_ok, 'finite clamp accepted non-finite fallback', scope)

print('hlcraft number: OK')
