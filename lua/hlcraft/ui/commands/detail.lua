local session = require('hlcraft.ui.session')
local results_state = require('hlcraft.ui.state.results')

local M = {}

function M.save_current(instance)
  local result = results_state.current_detail_result(instance)
  if not result then
    return false, nil
  end
  return session.save(instance, result.name)
end

function M.close_or_quit(instance)
  if instance.state.field_editor and instance.state.field_editor.field then
    require('hlcraft.ui.commands.editor').close(instance)
    return true, nil
  end
  instance:quit_or_back()
  return true, nil
end

return M
