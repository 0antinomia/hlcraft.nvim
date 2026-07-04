local actions = require('hlcraft.ui.actions')
local context = require('hlcraft.ui.context')
local numbers = require('hlcraft.core.number')
local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local navigation = require('hlcraft.ui.navigation')
local prompt = require('hlcraft.ui.prompt')
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

local function feed_fallback(instance, fallback_key)
  if fallback_key then
    return M.feed_normal_key(instance, fallback_key)
  end
  return false
end

function M.run_action(instance, action, ...)
  local ok = actions.dispatch(instance, action, ...)
  return ok
end

function M.run_search_action(instance, action)
  if scene.current_name(instance) ~= 'search' then
    return false
  end
  return M.run_action(instance, action)
end

function M.toggle_dynamic_color(instance)
  if context.current_field_kind(instance) ~= 'color' then
    return false
  end
  return M.run_action(instance, 'toggle_dynamic')
end

function M.cycle_dynamic_preset(instance, fallback_key)
  if not context.color_field_is_dynamic(instance) then
    return feed_fallback(instance, fallback_key)
  end

  return M.run_action(instance, 'cycle_dynamic_preset')
end

function M.adjust_dynamic_color(instance, delta)
  if not context.color_field_is_dynamic(instance) then
    return false
  end

  local step = numbers.to_finite(delta, 0)
  if context.current_dynamic_editor_row_key(instance) == 'dynamic_phase' then
    local dynamic = context.current_color_dynamic(instance)
    return M.run_action(
      instance,
      'set_dynamic_phase',
      numbers.to_finite(dynamic.phase, 0) + (step * ui_fields.dynamic_phase_step)
    )
  end
  return M.run_action(instance, 'adjust_dynamic_duration', step * ui_fields.dynamic_duration_step)
end

function M.open_dynamic_raw_json(instance)
  if not context.color_field_is_dynamic(instance) then
    return false
  end
  return M.run_action(instance, 'open_dynamic_raw_json')
end

function M.adjust_color(instance, channel, delta, fallback_key)
  if context.color_field_is_dynamic(instance) then
    return true
  end
  if context.current_field_kind(instance) == 'color' then
    return M.run_action(instance, 'adjust_color', channel, delta)
  end
  return feed_fallback(instance, fallback_key)
end

function M.set_color(instance, value, fallback_key)
  if context.current_field_kind(instance) ~= 'color' then
    return feed_fallback(instance, fallback_key)
  end
  return M.run_action(instance, 'set_color', value)
end

function M.adjust_blend(instance, delta, fallback_key)
  if context.current_field_kind(instance) ~= 'blend' then
    return feed_fallback(instance, fallback_key)
  end
  return M.run_action(instance, 'adjust_blend', delta)
end

function M.unset_blend(instance, fallback_key)
  if context.current_field_kind(instance) ~= 'blend' then
    return feed_fallback(instance, fallback_key)
  end
  return M.run_action(instance, 'set_blend', nil)
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
    return prompt.input({ prompt = field .. ': ' }, function(value)
      return M.set_color(instance, value)
    end, { notify_errors = false })
  end

  if kind == 'group' then
    return prompt.input({ prompt = 'Group: ' }, function(value)
      return M.run_action(instance, 'set_group', value)
    end, { notify_errors = false })
  end

  if kind == 'blend' then
    return prompt.input({ prompt = 'Blend: ' }, function(value)
      return M.run_action(instance, 'set_blend', value)
    end, { notify_errors = false })
  end

  return false
end

function M.jump_to_input_at_cursor(instance, insert)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end
  local input = buffer_fields.get_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
  if not input then
    return false
  end
  navigation.jump_to_row(instance, input.start_row + 1, insert)
  return true
end

return M
