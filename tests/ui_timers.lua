local h = require('tests.helpers')
local scope = 'hlcraft ui timers'

local timers = require('hlcraft.ui.timers')

local stopped = 0
local closed = 0
local timer = {
  stop = function()
    stopped = stopped + 1
  end,
  close = function()
    closed = closed + 1
  end,
}

local instance = {
  state = {
    debounce_timer = timer,
  },
}
timers.stop_debounce(instance)
h.assert_true(instance.state.debounce_timer == nil, 'debounce timer was not cleared', scope)
h.assert_equal(stopped, 1, 'debounce timer stop was not called', scope)
h.assert_equal(closed, 1, 'debounce timer close was not called', scope)

timers.stop_debounce({ state = {} })
local missing_instance_ok = pcall(timers.stop_debounce, nil)
h.assert_true(not missing_instance_ok, 'debounce timer stop accepted missing instance', scope)
local invalid_state_ok = pcall(timers.stop_debounce, { state = false })
h.assert_true(not invalid_state_ok, 'debounce timer stop accepted invalid state', scope)
local invalid_timer_instance = {
  state = {
    debounce_timer = {},
  },
}
local invalid_timer_ok = pcall(timers.stop_debounce, invalid_timer_instance)
h.assert_true(not invalid_timer_ok, 'debounce timer stop accepted invalid timer handle', scope)
h.assert_true(
  invalid_timer_instance.state.debounce_timer ~= nil,
  'failed debounce timer stop cleared invalid timer',
  scope
)

print('hlcraft ui timers: OK')
