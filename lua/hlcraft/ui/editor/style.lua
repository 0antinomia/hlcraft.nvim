local context = require('hlcraft.ui.editor.context')
local session = require('hlcraft.ui.session')

local M = {}

function M.next_boolean(value)
  if value == nil then
    return true, nil
  end
  if value == true then
    return false, nil
  end
  if value == false then
    return nil, nil
  end
  return nil, 'Style value must be boolean or nil'
end

function M.toggle(instance, result, key)
  local name = context.result_name(result, 'style editor')
  key = context.field_key(key, 'style editor')
  local next_value, err = M.next_boolean(session.field_value(name, key))
  if err then
    return false, err
  end
  return session.set_style(instance, name, key, next_value)
end

return M
