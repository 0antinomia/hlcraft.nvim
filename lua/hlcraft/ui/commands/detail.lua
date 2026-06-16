local scene = require('hlcraft.ui.scene')

local M = {}

function M.save_current(instance)
  if not instance.state.detail_index then
    return false, nil
  end
  return require('hlcraft.ui.scene.detail').handle(instance, 'save')
end

function M.close_or_quit(instance)
  return scene.back(instance)
end

return M
