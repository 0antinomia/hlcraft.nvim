local numbers = require('hlcraft.core.number')

local M = {}

local function assert_timeout(value, label, allow_zero)
  if type(value) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  local minimum = allow_zero and 0 or 1
  if not numbers.is_finite(value) or math.floor(value) ~= value or value < minimum then
    local range = allow_zero and 'a non-negative finite integer' or 'a positive finite integer'
    error(('%s must be %s'):format(label, range), 3)
  end
  return value
end

local function assert_callback(callback)
  if type(callback) ~= 'function' then
    error('timer callback must be a function', 3)
  end
  return callback
end

function M.stop(timer)
  if not timer then
    return
  end

  if timer.stop then
    pcall(function()
      timer:stop()
    end)
  end
  if timer.close then
    pcall(function()
      timer:close()
    end)
  end
end

local function start(delay_ms, repeat_ms, callback)
  callback = assert_callback(callback)
  local ok, timer = pcall(vim.uv.new_timer)
  if not ok or not timer then
    return nil
  end

  local started = pcall(function()
    timer:start(delay_ms, repeat_ms, callback)
  end)
  if not started then
    M.stop(timer)
    return nil
  end

  return timer
end

function M.repeating(interval_ms, callback)
  interval_ms = assert_timeout(interval_ms, 'repeating timer interval', false)
  return start(interval_ms, interval_ms, callback)
end

function M.once(delay_ms, callback)
  delay_ms = assert_timeout(delay_ms, 'one-shot timer delay', true)
  return start(delay_ms, 0, callback)
end

return M
