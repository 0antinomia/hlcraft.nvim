local context = require('hlcraft.ui.editor.context')
local session = require('hlcraft.ui.session')

local M = {}

function M.set(instance, result, group_name)
  return session.set_group(instance, context.result_name(result, 'group editor'), group_name)
end

function M.known_groups()
  return session.known_groups()
end

return M
