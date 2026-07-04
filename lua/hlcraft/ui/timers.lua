local M = {}

local core_timers = require('hlcraft.core.timers')

function M.stop(timer)
  core_timers.stop(timer)
end

function M.stop_debounce(instance)
  local timer = instance and instance.state and instance.state.debounce_timer or nil
  if not timer then
    return
  end

  M.stop(timer)
  instance.state.debounce_timer = nil
end

return M
