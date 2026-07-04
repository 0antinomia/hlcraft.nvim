local M = {}

function M.stop(timer)
  if not timer then
    return
  end

  if timer.stop then
    timer:stop()
  end
  if timer.close then
    pcall(function()
      timer:close()
    end)
  end
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
