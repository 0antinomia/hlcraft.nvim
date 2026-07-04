local h = require('tests.helpers')
local scope = 'hlcraft color'

local color = require('hlcraft.core.color')

h.assert_equal(color.int_to_hex(nil), 'NONE', 'nil int color did not normalize to NONE', scope)
h.assert_equal(color.int_to_hex('bad'), 'NONE', 'string int color did not normalize to NONE', scope)
h.assert_equal(color.int_to_hex(-1), 'NONE', 'negative int color did not normalize to NONE', scope)
h.assert_equal(color.int_to_hex(0x1000000), 'NONE', 'out-of-range int color did not normalize to NONE', scope)
h.assert_equal(color.int_to_hex(0xabcdef), '#abcdef', 'valid int color did not normalize', scope)
h.assert_equal(color.clamp_channel(-1), 0, 'negative channel was not clamped', scope)
h.assert_equal(color.clamp_channel(0 / 0), 0, 'NaN channel was not clamped', scope)
h.assert_equal(color.clamp_channel(255.9), 255, 'high channel was not clamped', scope)
h.assert_equal(color.clamp_channel(127.5), 128, 'channel was not rounded', scope)
h.assert_equal(color.rgb_to_hex(127.5, -20, 300), '#8000ff', 'rgb hex conversion changed', scope)
h.assert_equal(
  select(2, color.normalize(123)),
  'Color must be a string or nil, got number',
  'numeric color error changed',
  scope
)
h.assert_equal(select(1, color.normalize('')), nil, 'blank color did not normalize to unset', scope)
h.assert_equal(select(1, color.normalize('NONE')), 'NONE', 'NONE color did not normalize', scope)
h.assert_equal(select(1, color.normalize('#ABCDEF')), '#abcdef', 'hex color did not normalize', scope)
h.assert_equal(color.int_to_rgb(0x123456), 0x12, 'red channel changed', scope)
h.assert_true(color.hex_to_int(123) == nil, 'numeric hex input did not fail safely', scope)
h.assert_true(color.name_to_int(123) == nil, 'numeric color name input did not fail safely', scope)
h.assert_equal(color.contrast_fg(123), '#808080', 'numeric contrast input did not use fallback', scope)
local invalid_rgb_ok = pcall(color.int_to_rgb, 0x1000000)
h.assert_true(not invalid_rgb_ok, 'RGB splitter accepted an out-of-range color', scope)
local fractional_rgb_ok = pcall(color.int_to_rgb, 1.5)
h.assert_true(not fractional_rgb_ok, 'RGB splitter accepted a fractional color', scope)

local _, green, blue = color.int_to_rgb(0x123456)
h.assert_equal(green, 0x34, 'green channel changed', scope)
h.assert_equal(blue, 0x56, 'blue channel changed', scope)

print('hlcraft color: OK')
