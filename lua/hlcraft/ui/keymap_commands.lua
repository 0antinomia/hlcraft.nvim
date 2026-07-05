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

local function assert_string(value, label)
  if type(value) ~= 'string' or value == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return value
end

local function assert_finite(value, label)
  if not numbers.is_finite(value) then
    error(('%s must be a finite number'):format(label), 3)
  end
  return value
end

local function assert_insert(insert)
  if type(insert) ~= 'boolean' then
    error('input jump insert flag must be boolean', 3)
  end
  return insert
end

function M.feed_normal_key(instance, lhs)
  lhs = assert_string(lhs, 'normal feed key')
  local win = window.get_win(instance)
  if not window.is_valid_win(win) or search_scene.is_on_row(instance) then
    return false
  end

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
  return true
end

local function feed_fallback(instance, fallback_key)
  if fallback_key == nil then
    return false
  end
  return M.feed_normal_key(instance, assert_string(fallback_key, 'fallback key'))
end

function M.run_action(instance, action, ...)
  action = assert_string(action, 'keymap action')
  local ok = actions.dispatch(instance, action, ...)
  return ok
end

function M.run_search_action(instance, action)
  action = assert_string(action, 'search action')
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
  delta = assert_finite(delta, 'dynamic adjustment delta')
  if not context.color_field_is_dynamic(instance) then
    return false
  end

  local step = delta
  if context.current_dynamic_editor_row_key(instance) == 'dynamic_phase' then
    local dynamic = context.current_color_dynamic(instance)
    return M.run_action(instance, 'set_dynamic_phase', dynamic.phase + (step * ui_fields.dynamic_phase_step))
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
  channel = assert_string(channel, 'color adjustment channel')
  delta = assert_finite(delta, 'color adjustment delta')
  if context.color_field_is_dynamic(instance) then
    return true
  end
  if context.current_field_kind(instance) == 'color' then
    return M.run_action(instance, 'adjust_color', channel, delta)
  end
  return feed_fallback(instance, fallback_key)
end

function M.set_color(instance, value, fallback_key)
  if type(value) ~= 'string' then
    error('color value must be a string', 2)
  end
  if context.current_field_kind(instance) ~= 'color' then
    return feed_fallback(instance, fallback_key)
  end
  return M.run_action(instance, 'set_color', value)
end

function M.adjust_blend(instance, delta, fallback_key)
  delta = assert_finite(delta, 'blend adjustment delta')
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

  if kind == 'color' then
    local field = context.current_field(instance)
    if context.color_field_is_dynamic(instance) then
      return M.run_action(instance, 'input_dynamic_row', { default_raw = true })
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
  insert = assert_insert(insert)
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
