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

timers.stop(timer)
h.assert_equal(stopped, 1, 'timer stop was not called', scope)
h.assert_equal(closed, 1, 'timer close was not called', scope)

local close_failed = false
timers.stop({
  close = function()
    close_failed = true
    error('already closed')
  end,
})
h.assert_true(close_failed, 'fallible timer close was not attempted', scope)

local instance = {
  state = {
    debounce_timer = timer,
  },
}
timers.stop_debounce(instance)
h.assert_true(instance.state.debounce_timer == nil, 'debounce timer was not cleared', scope)
h.assert_equal(stopped, 2, 'debounce timer stop was not called', scope)
h.assert_equal(closed, 2, 'debounce timer close was not called', scope)

timers.stop_debounce({ state = {} })
timers.stop_debounce(nil)

print('hlcraft ui timers: OK')
