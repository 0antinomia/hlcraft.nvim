local h = require('tests.helpers')
local scope = 'hlcraft core timers'

local timers = require('hlcraft.core.timers')

local once = timers.once(1, function() end)
if once then
  timers.stop(once)
end

local repeating = timers.repeating(1, function() end)
if repeating then
  timers.stop(repeating)
end

local invalid_once_delay_ok = pcall(timers.once, -1, function() end)
h.assert_true(not invalid_once_delay_ok, 'one-shot timer accepted negative delay', scope)
local fractional_once_delay_ok = pcall(timers.once, 1.5, function() end)
h.assert_true(not fractional_once_delay_ok, 'one-shot timer accepted fractional delay', scope)
local infinite_once_delay_ok = pcall(timers.once, math.huge, function() end)
h.assert_true(not infinite_once_delay_ok, 'one-shot timer accepted infinite delay', scope)
local invalid_once_callback_ok = pcall(timers.once, 0, nil)
h.assert_true(not invalid_once_callback_ok, 'one-shot timer accepted missing callback', scope)

local zero_repeat_ok = pcall(timers.repeating, 0, function() end)
h.assert_true(not zero_repeat_ok, 'repeating timer accepted zero interval', scope)
local fractional_repeat_ok = pcall(timers.repeating, 1.5, function() end)
h.assert_true(not fractional_repeat_ok, 'repeating timer accepted fractional interval', scope)
local invalid_repeat_callback_ok = pcall(timers.repeating, 1, false)
h.assert_true(not invalid_repeat_callback_ok, 'repeating timer accepted invalid callback', scope)

print('hlcraft core timers: OK')
