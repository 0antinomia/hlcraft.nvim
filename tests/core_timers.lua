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

timers.stop(nil)
local invalid_timer_ok = pcall(timers.stop, false)
h.assert_true(not invalid_timer_ok, 'timer stop accepted non-handle value', scope)
local missing_timer_methods_ok = pcall(timers.stop, {})
h.assert_true(not missing_timer_methods_ok, 'timer stop accepted handle without stop or close', scope)
local invalid_timer_stop_ok = pcall(timers.stop, { stop = false })
h.assert_true(not invalid_timer_stop_ok, 'timer stop accepted non-function stop method', scope)
local invalid_timer_close_ok = pcall(timers.stop, { close = false })
h.assert_true(not invalid_timer_close_ok, 'timer stop accepted non-function close method', scope)

local failed_stop_attempted = false
local failed_close_attempted = false
local failed_cleanup_ok, failed_cleanup_err = pcall(timers.stop, {
  stop = function()
    failed_stop_attempted = true
    error('stop failed')
  end,
  close = function()
    failed_close_attempted = true
    error('close failed')
  end,
})
h.assert_true(not failed_cleanup_ok, 'timer cleanup swallowed operational failures', scope)
h.assert_true(failed_stop_attempted, 'timer cleanup skipped stop', scope)
h.assert_true(failed_close_attempted, 'timer cleanup stopped before close', scope)
h.assert_true(
  tostring(failed_cleanup_err):find('stop failed', 1, true) ~= nil
    and tostring(failed_cleanup_err):find('close failed', 1, true) ~= nil,
  'timer cleanup did not aggregate stop and close failures',
  scope
)

print('hlcraft core timers: OK')
