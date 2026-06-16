local session = require('hlcraft.ui.session')

local M = {}

function M.set(instance, result, group_name)
  return session.set_group(instance, result.name, group_name)
end

function M.known_groups()
  return session.known_groups()
end

return M
