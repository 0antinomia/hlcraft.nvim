local actions = require('hlcraft.ui.actions')
local context = require('hlcraft.ui.context')
local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local navigation = require('hlcraft.ui.navigation')
local scene = require('hlcraft.ui.scene')
local search_scene = require('hlcraft.ui.scene.search')
local ui_fields = require('hlcraft.ui.fields')
local window = require('hlcraft.ui.workspace.window')

local M = {}

function M.feed_normal_key(instance, lhs)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) or search_scene.is_on_row(instance) then
    return false
  end

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
  return true
end

function M.run_action(instance, action, ...)
  local ok = actions.dispatch(instance, action, ...)
  return ok
end

function M.run_search_action(instance, action)
  if scene.current_name(instance) ~= 'search' then
    return false
  end
  actions.dispatch(instance, action)
  return true
end

function M.toggle_dynamic_color(instance)
  if context.current_field_kind(instance) ~= 'color' then
    return false
  end
  M.run_action(instance, 'toggle_dynamic')
  return true
end

function M.cycle_dynamic_preset(instance, fallback_key)
  if not context.color_field_is_dynamic(instance) then
    if fallback_key then
      M.feed_normal_key(instance, fallback_key)
    end
    return false
  end

  M.run_action(instance, 'cycle_dynamic_preset')
  return true
end

function M.adjust_dynamic_color(instance, delta)
  if not context.color_field_is_dynamic(instance) then
    return false
  end

  if context.current_dynamic_editor_row_key(instance) == 'dynamic_phase' then
    local dynamic = context.current_color_dynamic(instance)
    M.run_action(instance, 'set_dynamic_phase', (tonumber(dynamic.phase) or 0) + (delta * ui_fields.dynamic_phase_step))
  else
    M.run_action(instance, 'adjust_dynamic_duration', delta * ui_fields.dynamic_duration_step)
  end
  return true
end

function M.open_dynamic_raw_json(instance)
  if not context.color_field_is_dynamic(instance) then
    return false
  end
  M.run_action(instance, 'open_dynamic_raw_json')
  return true
end

function M.adjust_color(instance, channel, delta, fallback_key)
  if context.color_field_is_dynamic(instance) then
    return true
  end
  if context.current_field_kind(instance) == 'color' then
    M.run_action(instance, 'adjust_color', channel, delta)
    return true
  end
  if fallback_key then
    M.feed_normal_key(instance, fallback_key)
    return true
  end
  return false
end

function M.set_color(instance, value, fallback_key)
  if context.current_field_kind(instance) ~= 'color' then
    if fallback_key then
      M.feed_normal_key(instance, fallback_key)
      return true
    end
    return false
  end
  M.run_action(instance, 'set_color', value)
  return true
end

function M.adjust_blend(instance, delta, fallback_key)
  if context.current_field_kind(instance) ~= 'blend' then
    if fallback_key then
      M.feed_normal_key(instance, fallback_key)
      return true
    end
    return false
  end
  M.run_action(instance, 'adjust_blend', delta)
  return true
end

function M.unset_blend(instance, fallback_key)
  if context.current_field_kind(instance) ~= 'blend' then
    if fallback_key then
      M.feed_normal_key(instance, fallback_key)
      return true
    end
    return false
  end
  M.run_action(instance, 'set_blend', nil)
  return true
end

function M.input_current_editor_field(instance)
  local kind = context.current_field_kind(instance)
  if not kind then
    return false
  end
  local field = instance.state.field_editor and instance.state.field_editor.field

  if kind == 'color' then
    if context.color_field_is_dynamic(instance) then
      M.run_action(instance, 'input_dynamic_row', { default_raw = true })
      return true
    end
    vim.ui.input({ prompt = field .. ': ' }, function(value)
      if value ~= nil then
        M.set_color(instance, value)
      end
    end)
    return true
  end

  if kind == 'group' then
    vim.ui.input({ prompt = 'Group: ' }, function(value)
      if value ~= nil then
        M.run_action(instance, 'set_group', value)
      end
    end)
    return true
  end

  if kind == 'blend' then
    vim.ui.input({ prompt = 'Blend: ' }, function(value)
      if value ~= nil then
        M.run_action(instance, 'set_blend', value)
      end
    end)
    return true
  end

  return false
end

function M.jump_to_input_at_cursor(instance, insert)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end
  local field = buffer_fields.get_field_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
  if not field then
    return false
  end
  navigation.jump_to_row(instance, field.line, insert)
  return true
end

return M
