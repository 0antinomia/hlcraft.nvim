local results_state = require('hlcraft.ui.state.results')
local workspace_render = require('hlcraft.ui.render.workspace')

local M = {}

function M.enter(instance, opts)
  instance.state.detail_index = opts and opts.index or instance.state.detail_index
end

function M.render(instance)
  results_state.update_results(instance)
  workspace_render.render(instance)
end

function M.back(instance)
  results_state.close_detail(instance)
  return true, nil
end

return M
