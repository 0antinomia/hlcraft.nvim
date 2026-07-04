local session = require('hlcraft.ui.session')

local M = {}

function M.next_boolean(value)
  if value == true then
    return false
  end
  if value == false then
    return nil
  end
  return true
end

function M.toggle(instance, result, key)
  return session.set_style(instance, result.name, key, M.next_boolean(session.field_value(result.name, key)))
end

return M
