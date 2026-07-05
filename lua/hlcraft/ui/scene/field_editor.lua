local detail_scene = require('hlcraft.ui.scene.detail')
local dynamic_model = require('hlcraft.dynamic.model')
local numbers = require('hlcraft.core.number')
local style_editor = require('hlcraft.ui.editor.style')
local field_editor_actions = require('hlcraft.ui.scene.field_editor_actions')
local prompt = require('hlcraft.ui.prompt')
local rows = require('hlcraft.ui.scene.rows')
local session = require('hlcraft.ui.session')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('field editor scene requires an instance', 3)
  end
  return instance.state
end

local function field_editor_state(state)
  if type(state.field_editor) ~= 'table' then
    error('field editor state must be a table', 3)
  end
  return state.field_editor
end

local function scene_state(state)
  if type(state.scene) ~= 'table' then
    error('field editor scene state must be a table', 3)
  end
  return state.scene
end

local function assert_action(action)
  if type(action) ~= 'string' or action == '' then
    error('field editor action must be a non-empty string', 3)
  end
  return action
end

local function assert_rerender(instance)
  if type(instance.rerender) ~= 'function' then
    error('field editor scene requires a rerender callback', 3)
  end
end

local function assert_field(field)
  if type(field) ~= 'string' or field == '' then
    error('field editor field must be a non-empty string', 3)
  end
  return field
end

local function detail_index(state)
  local index = state.detail_index
  if type(index) ~= 'number' then
    error('field editor detail index must be a number', 3)
  end
  if not numbers.is_finite(index) or math.floor(index) ~= index or index < 1 then
    error('field editor detail index must be a positive finite integer', 3)
  end
  return index
end

function M.current_result(instance)
  return detail_scene.current_result(instance)
end

function M.current_field(instance)
  local field = field_editor_state(instance_state(instance)).field
  if field ~= nil then
    assert_field(field)
  end
  return field
end

function M.editor_row_at_cursor(instance)
  return rows.editor_row_at_cursor(instance)
end

local function menu_row_at_cursor(instance)
  return rows.detail_menu_at_cursor(instance)
end

local function dynamic_value(result, field)
  if not result or not dynamic_model.channel_set[field] then
    return nil
  end
  return session.dynamic_value(result.name, field)
end

local function prompt_dynamic_value(instance, action, prompt_text, default)
  return prompt.input({ prompt = prompt_text, default = default }, function(value)
    return M.handle(instance, action, value)
  end)
end

local function optional_table(opts, label)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error(('%s options must be a table'):format(label), 3)
  end
  return opts
end

local function optional_string(value, label)
  if value ~= nil and (type(value) ~= 'string' or value == '') then
    error(('%s must be a non-empty string or nil'):format(label), 3)
  end
  return value
end

local function optional_boolean(value, label)
  if value ~= nil and type(value) ~= 'boolean' then
    error(('%s must be boolean or nil'):format(label), 3)
  end
  return value == true
end

local function selected_editor_row_key(instance)
  local row = M.editor_row_at_cursor(instance)
  return row and row.key or nil
end

function M.open(instance, key)
  local field_editor = field_editor_state(instance_state(instance))
  key = assert_field(key)
  assert_rerender(instance)
  field_editor.field = key
  instance:rerender()
end

function M.close(instance)
  local field_editor = field_editor_state(instance_state(instance))
  assert_rerender(instance)
  field_editor.field = nil
  instance:rerender()
end

function M.selected_dynamic_row_key(instance)
  local result = M.current_result(instance)
  local field = M.current_field(instance)
  if not dynamic_value(result, field) then
    return nil
  end
  return selected_editor_row_key(instance)
end

function M.input_dynamic_row(instance, opts)
  opts = optional_table(opts, 'dynamic row input')
  local default_raw = optional_boolean(opts.default_raw, 'dynamic row raw fallback')
  local result = M.current_result(instance)
  local field = M.current_field(instance)
  local dynamic = dynamic_value(result, field)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  local row_key = selected_editor_row_key(instance)
  if row_key == 'dynamic_loop' then
    return prompt_dynamic_value(instance, 'set_dynamic_loop', 'Loop: ', dynamic.loop)
  end
  if row_key == 'dynamic_phase' then
    return prompt_dynamic_value(instance, 'set_dynamic_phase', 'Phase: ', ('%.2f'):format(dynamic.phase))
  end
  if row_key == 'dynamic_raw_json' or default_raw then
    return require('hlcraft.ui.raw_dynamic').open(instance, result, field)
  end

  return false, nil
end

function M.enter(instance, opts)
  local state = instance_state(instance)
  local field_editor = field_editor_state(state)
  local current_scene = scene_state(state)
  opts = optional_table(opts, 'field editor entry')
  local field = optional_string(opts.field, 'field editor field')
  optional_string(opts.kind, 'field editor kind')
  field_editor.field = field ~= nil and field or optional_string(field_editor.field, 'field editor field')
  current_scene.field = field_editor.field
end

function M.render(instance)
  field_editor_state(instance_state(instance))
  require('hlcraft.ui.scene.search').update_results(instance)
  require('hlcraft.ui.render.field_editor').render(instance)
end

function M.back(instance)
  local state = instance_state(instance)
  local field_editor = field_editor_state(state)
  local index = detail_index(state)
  assert_rerender(instance)
  field_editor.field = nil
  require('hlcraft.ui.scene').set(instance, 'detail', { index = index })
  instance:rerender()
  return true, nil
end

function M.activate(instance)
  assert_rerender(instance)
  local result = M.current_result(instance)
  local field = M.current_field(instance)
  if dynamic_value(result, field) then
    local row_key = M.selected_dynamic_row_key(instance)
    if row_key == 'dynamic_loop' or row_key == 'dynamic_phase' or row_key == 'dynamic_raw_json' then
      return M.input_dynamic_row(instance)
    end
  end

  if M.current_field(instance) == 'group' then
    local editor_row = M.editor_row_at_cursor(instance)
    local row_key = editor_row and editor_row.key or nil
    if type(row_key) == 'string' and row_key:sub(1, 6) == 'group:' then
      return M.handle(instance, 'set_group', row_key:sub(7))
    end
    if row_key == 'new_group' then
      return prompt.input({ prompt = 'Group: ' }, function(value)
        return M.handle(instance, 'set_group', value)
      end)
    end
  end

  local row = menu_row_at_cursor(instance)
  if not row or not result then
    return false, nil
  end

  if row.kind ~= 'boolean' then
    M.open(instance, row.key)
    return true, nil
  end

  return style_editor.toggle(instance, result, row.key)
end

function M.handle(instance, action, ...)
  instance_state(instance)
  action = assert_action(action)
  if action == 'activate' then
    return M.activate(instance)
  end
  if action == 'save' then
    return require('hlcraft.ui.scene.detail').handle(instance, 'save')
  end
  if action == 'selected_dynamic_row_key' then
    return true, M.selected_dynamic_row_key(instance)
  end
  if action == 'input_dynamic_row' then
    return M.input_dynamic_row(instance, ...)
  end

  local result = M.current_result(instance)
  local field = M.current_field(instance)
  if not result or not field then
    return false, 'No field editor is active'
  end

  local matched, ok, err = field_editor_actions.handle(instance, action, result, field, ...)
  if matched then
    return ok, err
  end

  return false, ('unsupported field editor action: %s'):format(tostring(action))
end

return M
