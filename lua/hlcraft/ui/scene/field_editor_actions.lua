local blend_editor = require('hlcraft.ui.editor.blend')
local color_editor = require('hlcraft.ui.editor.color')
local core_fields = require('hlcraft.core.fields')
local dynamic_editor = require('hlcraft.ui.editor.dynamic')
local group_editor = require('hlcraft.ui.editor.group')
local session = require('hlcraft.ui.session')
local ui_fields = require('hlcraft.ui.fields')

local M = {}

local function finish_edit(instance, ok, err, preserve_field)
  if not ok then
    return false, err
  end

  if preserve_field then
    instance.state.field_editor.field = preserve_field
  end
  return true, nil
end

local function color_is_dynamic(result, field)
  return session.dynamic_value(result.name, field) ~= nil
end

local color_actions = {
  set_color = function(instance, result, field, ...)
    if color_is_dynamic(result, field) then
      return false, 'Static color controls are disabled while dynamic is active'
    end
    return color_editor.set(instance, result, field, ...)
  end,
  adjust_color = function(instance, result, field, ...)
    if color_is_dynamic(result, field) then
      return false, 'Static color controls are disabled while dynamic is active'
    end
    return color_editor.adjust(instance, result, field, ...)
  end,
  toggle_dynamic = function(instance, result, field)
    return dynamic_editor.toggle(instance, result, field)
  end,
  cycle_dynamic_preset = function(instance, result, field)
    return dynamic_editor.cycle_preset(instance, result, field)
  end,
  adjust_dynamic_duration = function(instance, result, field, ...)
    return dynamic_editor.adjust_duration(instance, result, field, ...)
  end,
  set_dynamic_loop = function(instance, result, field, ...)
    return dynamic_editor.set_loop(instance, result, field, ...)
  end,
  set_dynamic_phase = function(instance, result, field, ...)
    return dynamic_editor.set_phase(instance, result, field, ...)
  end,
  open_dynamic_raw_json = function(instance, result, field)
    require('hlcraft.ui.raw_dynamic').open(instance, result, field)
    return true, nil
  end,
}

local field_kind_actions = {
  group = {
    set_group = function(instance, result, _, ...)
      return group_editor.set(instance, result, ...)
    end,
  },
  blend = {
    set_blend = function(instance, result, _, ...)
      return blend_editor.set(instance, result, ...)
    end,
    adjust_blend = function(instance, result, _, ...)
      return blend_editor.adjust(instance, result, ...)
    end,
  },
}

function M.handle(instance, action, result, field, ...)
  if core_fields.color_set[field] and color_actions[action] then
    local ok, err = color_actions[action](instance, result, field, ...)
    return true, finish_edit(instance, ok, err, field)
  end

  local kind = ui_fields.detail_kinds[field]
  local actions = field_kind_actions[kind]
  local handler = actions and actions[action] or nil
  if handler then
    local ok, err = handler(instance, result, field, ...)
    return true, finish_edit(instance, ok, err, field)
  end

  return false, nil, nil
end

return M
