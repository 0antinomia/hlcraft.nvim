local h = require('tests.helpers')
local scope = 'hlcraft color'

local color = require('hlcraft.core.color')

h.assert_equal(color.clamp_channel(-1), 0, 'negative channel was not clamped', scope)
h.assert_equal(color.clamp_channel(255.9), 255, 'high channel was not clamped', scope)
h.assert_equal(color.clamp_channel(127.5), 128, 'channel was not rounded', scope)
h.assert_equal(color.rgb_to_hex(127.5, -20, 300), '#8000ff', 'rgb hex conversion changed', scope)
h.assert_equal(color.int_to_rgb(0x123456), 0x12, 'red channel changed', scope)

local _, green, blue = color.int_to_rgb(0x123456)
h.assert_equal(green, 0x34, 'green channel changed', scope)
h.assert_equal(blue, 0x56, 'blue channel changed', scope)

print('hlcraft color: OK')
