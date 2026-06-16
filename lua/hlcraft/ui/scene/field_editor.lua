local workspace_render = require('hlcraft.ui.render.workspace')

local M = {}

function M.enter(instance, opts)
  instance.state.field_editor.field = opts and opts.field or instance.state.field_editor.field
  instance.state.scene.field = instance.state.field_editor.field
end

function M.render(instance)
  require('hlcraft.ui.scene.search').update_results(instance)
  workspace_render.render(instance)
end

function M.back(instance)
  instance.state.field_editor.field = nil
  require('hlcraft.ui.scene').set(instance, 'detail', { index = instance.state.detail_index })
  instance:rerender()
  return true, nil
end

function M.handle(instance, action)
  if action == 'activate' then
    -- Temporary Task 3 bridge until editor actions move into scenes in Task 4.
    require('hlcraft.ui.commands.editor').activate(instance)
    return true, nil
  end
  if action == 'save' then
    return require('hlcraft.ui.scene.detail').handle(instance, 'save')
  end
  return false, ('unsupported field editor action: %s'):format(tostring(action))
end

return M
