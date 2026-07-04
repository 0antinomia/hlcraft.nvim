local notify = require('hlcraft.notify')
local scene = require('hlcraft.ui.scene')

local M = {}

function M.dispatch(instance, action, ...)
  local ok, err = scene.handle(instance, action, ...)
  if ok == false and err ~= nil then
    notify.error(err)
  end
  return ok, err
end

function M.back(instance)
  local ok, err = scene.back(instance)
  if ok == false and err ~= nil then
    notify.error(err)
  end
  return ok, err
end

return M
