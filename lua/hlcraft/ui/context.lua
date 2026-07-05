local detail_scene = require('hlcraft.ui.scene.detail')
local field_editor_scene = require('hlcraft.ui.scene.field_editor')
local scene = require('hlcraft.ui.scene')
local session = require('hlcraft.ui.session')
local tables = require('hlcraft.core.tables')
local ui_fields = require('hlcraft.ui.fields')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('UI context requires an instance', 3)
  end
  return instance.state
end

local function field_editor_state(state)
  if type(state.field_editor) ~= 'table' then
    error('UI context field editor state must be a table', 3)
  end
  return state.field_editor
end

local function result_list(state)
  return tables.assert_sequence(state.results, 'UI context results', 3)
end

local function current_field_state(state)
  local field = field_editor_state(state).field
  if field ~= nil and (type(field) ~= 'string' or field == '') then
    error('UI context field must be a non-empty string or nil', 3)
  end
  return field
end

function M.editor_scene_is_active(instance)
  local state = instance_state(instance)
  local current_scene = scene.current_name(instance)
  return state.detail_index ~= nil and (current_scene == 'detail' or current_scene == 'field_editor')
end

function M.current_field(instance)
  return current_field_state(instance_state(instance))
end

function M.current_field_kind(instance)
  if not M.editor_scene_is_active(instance) then
    return nil
  end
  local field = M.current_field(instance)
  if not field then
    return nil
  end
  local kind = ui_fields.detail_kinds[field]
  if kind == nil then
    error(('UI context field is not supported: %s'):format(field), 2)
  end
  return kind
end

function M.current_result(instance)
  result_list(instance_state(instance))
  return detail_scene.current_result(instance)
end

function M.current_color_dynamic(instance)
  local field = M.current_field(instance)
  local result = M.current_result(instance)
  if M.current_field_kind(instance) ~= 'color' or not result then
    return nil
  end
  return session.dynamic_value(result.name, field)
end

function M.color_field_is_dynamic(instance)
  return M.current_color_dynamic(instance) ~= nil
end

function M.current_dynamic_editor_row_key(instance)
  if not M.color_field_is_dynamic(instance) then
    return nil
  end
  local row = field_editor_scene.editor_row_at_cursor(instance)
  return row and row.key or nil
end

return M
