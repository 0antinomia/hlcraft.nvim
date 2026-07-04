local M = {}

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
  return start(interval_ms, interval_ms, callback)
end

function M.once(delay_ms, callback)
  return start(delay_ms, 0, callback)
end

return M
