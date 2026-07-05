local M = {}

local core_timers = require('hlcraft.core.timers')

function M.stop(timer)
  core_timers.stop(timer)
end

function M.stop_debounce(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('debounce timer stop requires an instance', 2)
  end
  local timer = instance.state.debounce_timer
  if not timer then
    return
  end

  M.stop(timer)
  instance.state.debounce_timer = nil
end

return M
