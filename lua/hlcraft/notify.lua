local M = {}

local function notify(level, message)
  if message == nil then
    return
  end
  vim.notify(('hlcraft: %s'):format(tostring(message)), level)
end

function M.error(message)
  notify(vim.log.levels.ERROR, message)
end

function M.warn(message)
  notify(vim.log.levels.WARN, message)
end

return M
