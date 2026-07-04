local detail_scene = require('hlcraft.ui.scene.detail')
local dynamic_model = require('hlcraft.dynamic.model')
local style_editor = require('hlcraft.ui.editor.style')
local field_editor_actions = require('hlcraft.ui.scene.field_editor_actions')
local prompt = require('hlcraft.ui.prompt')
local rows = require('hlcraft.ui.scene.rows')
local session = require('hlcraft.ui.session')

local M = {}

function M.current_result(instance)
  return detail_scene.current_result(instance)
end

function M.current_field(instance)
  return instance.state.field_editor and instance.state.field_editor.field or nil
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

local function selected_editor_row_key(instance)
  local row = M.editor_row_at_cursor(instance)
  return row and row.key or nil
end

function M.open(instance, key)
  instance.state.field_editor.field = key
  instance:rerender()
end

function M.close(instance)
  instance.state.field_editor.field = nil
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
  if row_key == 'dynamic_raw_json' or opts.default_raw then
    return require('hlcraft.ui.raw_dynamic').open(instance, result, field)
  end

  return false, nil
end

function M.enter(instance, opts)
  opts = optional_table(opts, 'field editor entry')
  instance.state.field_editor.field = opts.field or instance.state.field_editor.field
  instance.state.scene.field = instance.state.field_editor.field
end

function M.render(instance)
  require('hlcraft.ui.scene.search').update_results(instance)
  require('hlcraft.ui.render.field_editor').render(instance)
end

function M.back(instance)
  instance.state.field_editor.field = nil
  require('hlcraft.ui.scene').set(instance, 'detail', { index = instance.state.detail_index })
  instance:rerender()
  return true, nil
end

function M.activate(instance)
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
