local notify = require('hlcraft.notify')
local scene = require('hlcraft.ui.scene')

local M = {}
local unpack = unpack or table.unpack

local function run_scene(fn)
  local call_ok, ok, err = xpcall(fn, debug.traceback)
  if not call_ok then
    notify.error(ok)
    return false, ok
  end
  if ok == false and err ~= nil then
    notify.error(err)
  end
  return ok, err
end

function M.dispatch(instance, action, ...)
  local args = { ... }
  local argc = select('#', ...)
  return run_scene(function()
    return scene.handle(instance, action, unpack(args, 1, argc))
  end)
end

function M.back(instance)
  return run_scene(function()
    return scene.back(instance)
  end)
end

return M
