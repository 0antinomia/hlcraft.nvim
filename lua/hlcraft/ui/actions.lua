local scene = require('hlcraft.ui.scene')

local M = {}

local function notify_error(err)
  if err then
    vim.notify(('hlcraft: %s'):format(err), vim.log.levels.ERROR)
  end
end

function M.dispatch(instance, action, ...)
  local ok, err = scene.handle(instance, action, ...)
  if ok == false and err ~= nil then
    notify_error(err)
  end
  return ok, err
end

function M.back(instance)
  local ok, err = scene.back(instance)
  if ok == false and err ~= nil then
    notify_error(err)
  end
  return ok, err
end

return M
