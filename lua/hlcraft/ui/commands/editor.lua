local field_editor_scene = require('hlcraft.ui.scene.field_editor')
local scene = require('hlcraft.ui.scene')

local M = {}

function M.open(instance, key)
  local ok, err = scene.set(instance, 'field_editor', { field = key })
  if not ok then
    return false, err
  end
  instance:rerender()
  return true, nil
end

function M.close(instance)
  field_editor_scene.close(instance)
  return true, nil
end

function M.activate(instance)
  return scene.handle(instance, 'activate')
end

function M.set_color(instance, value)
  return scene.handle(instance, 'set_color', value)
end

function M.adjust_color(instance, channel, delta)
  return scene.handle(instance, 'adjust_color', channel, delta)
end

function M.toggle_dynamic(instance)
  return scene.handle(instance, 'toggle_dynamic')
end

function M.cycle_dynamic_mode(instance)
  return scene.handle(instance, 'cycle_dynamic_mode')
end

function M.adjust_dynamic_speed(instance, delta)
  return scene.handle(instance, 'adjust_dynamic_speed', delta)
end

function M.set_dynamic_param(instance, name, value)
  return scene.handle(instance, 'set_dynamic_param', name, value)
end

function M.selected_param_name(instance)
  return field_editor_scene.selected_param_name(instance)
end

M.selected_dynamic_param_name = M.selected_param_name

function M.adjust_dynamic_param(instance, name, delta)
  return scene.handle(instance, 'adjust_dynamic_param', name, delta)
end

function M.select_dynamic_palette(instance, delta)
  return scene.handle(instance, 'select_dynamic_palette', delta)
end

function M.add_dynamic_palette_color(instance)
  return scene.handle(instance, 'add_dynamic_palette_color')
end

function M.delete_dynamic_palette_color(instance)
  return scene.handle(instance, 'delete_dynamic_palette_color')
end

function M.set_dynamic_palette_color(instance, value)
  return scene.handle(instance, 'set_dynamic_palette_color', value)
end

function M.set_group(instance, group_name)
  return scene.handle(instance, 'set_group', group_name)
end

function M.set_blend(instance, value)
  return scene.handle(instance, 'set_blend', value)
end

function M.adjust_blend(instance, delta)
  return scene.handle(instance, 'adjust_blend', delta)
end

return M
