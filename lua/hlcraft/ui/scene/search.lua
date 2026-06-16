local results_state = require('hlcraft.ui.state.results')
local workspace_render = require('hlcraft.ui.render.workspace')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')

local M = {}

function M.enter(instance)
  instance.state.scene.name = 'search'
end

function M.render(instance)
  results_state.update_results(instance)
  workspace_render.render(instance)
end

function M.back(instance)
  if instance.state.detail_index then
    results_state.close_detail(instance)
    return true, nil
  end
  lifecycle.close(instance)
  return true, nil
end

return M
