local blend_editor = require('hlcraft.ui.editor.blend')
local color_editor = require('hlcraft.ui.editor.color')
local detail_scene = require('hlcraft.ui.scene.detail')
local dynamic_editor = require('hlcraft.ui.editor.dynamic')
local group_editor = require('hlcraft.ui.editor.group')
local session = require('hlcraft.ui.session')
local ui_fields = require('hlcraft.ui.fields')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local color_fields = {
  fg = true,
  bg = true,
  sp = true,
}

local function notify_error(message)
  if message then
    vim.notify(('hlcraft: %s'):format(message), vim.log.levels.ERROR)
  end
end

function M.current_result(instance)
  return detail_scene.current_result(instance)
end

function M.current_field(instance)
  return instance.state.field_editor and instance.state.field_editor.field or nil
end

function M.editor_row_at_cursor(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end
  local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
  for key, row in pairs(instance.state.geometry.editor_rows or {}) do
    if row.line == cursor_line then
      row.key = row.key or key
      return row
    end
  end
end

local function menu_row_at_cursor(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end

  local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
  for _, row in pairs(instance.state.geometry.detail_menu or {}) do
    if row.line == cursor_line then
      return row
    end
  end
end

local function finish_edit(instance, ok, err, preserve_field)
  if not ok then
    return false, err
  end

  if preserve_field then
    instance.state.field_editor.field = preserve_field
  end
  return true, nil
end

local function dynamic_value(result, field)
  if not result or not color_fields[field] then
    return nil
  end
  return session.dynamic_value(result.name, field)
end

local function prompt_dynamic_value(instance, action, prompt, default)
  vim.ui.input({ prompt = prompt, default = default }, function(value)
    if value == nil then
      return
    end
    local ok, err = M.handle(instance, action, value)
    if not ok and err then
      notify_error(err)
    end
  end)
  return true, nil
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

function M.selected_param_name(instance)
  return nil
end

M.selected_dynamic_param_name = M.selected_param_name

function M.selected_dynamic_row_key(instance)
  local result = M.current_result(instance)
  local field = M.current_field(instance)
  if not dynamic_value(result, field) then
    return nil
  end
  return selected_editor_row_key(instance)
end

function M.input_dynamic_row(instance, opts)
  opts = opts or {}
  local result = M.current_result(instance)
  local field = M.current_field(instance)
  local dynamic = dynamic_value(result, field)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  local row_key = selected_editor_row_key(instance)
  if row_key == 'dynamic_loop' then
    return prompt_dynamic_value(instance, 'set_dynamic_loop', 'Loop: ', dynamic.loop or 'repeat')
  end
  if row_key == 'dynamic_phase' then
    return prompt_dynamic_value(instance, 'set_dynamic_phase', 'Phase: ', ('%.2f'):format(dynamic.phase or 0))
  end
  if row_key == 'dynamic_raw_json' or opts.default_raw then
    require('hlcraft.ui.raw_dynamic').open(instance, result, field)
    return true, nil
  end

  return false, nil
end

function M.enter(instance, opts)
  instance.state.field_editor.field = opts and opts.field or instance.state.field_editor.field
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
      vim.ui.input({ prompt = 'Group: ' }, function(value)
        if value == nil then
          return
        end
        local ok, err = M.handle(instance, 'set_group', value)
        if not ok and err then
          notify_error(err)
        end
      end)
      return true, nil
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

  local runtime_value = session.field_value(result.name, row.key)
  local next_value = true
  if runtime_value == true then
    next_value = false
  elseif runtime_value == false then
    next_value = nil
  end

  return session.set_style(instance, result.name, row.key, next_value)
end

function M.handle(instance, action, ...)
  if action == 'activate' then
    return M.activate(instance)
  end
  if action == 'save' then
    return require('hlcraft.ui.scene.detail').handle(instance, 'save')
  end
  if action == 'selected_param_name' or action == 'selected_dynamic_param_name' then
    return true, M.selected_param_name(instance)
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

  if action == 'set_color' and color_fields[field] then
    if session.dynamic_value(result.name, field) then
      return false, 'Static color controls are disabled while dynamic is active'
    end
    local ok, err = color_editor.set(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'adjust_color' and color_fields[field] then
    if session.dynamic_value(result.name, field) then
      return false, 'Static color controls are disabled while dynamic is active'
    end
    local ok, err = color_editor.adjust(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'toggle_dynamic' and color_fields[field] then
    local ok, err = dynamic_editor.toggle(instance, result, field)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'cycle_dynamic_preset' and color_fields[field] then
    local ok, err = dynamic_editor.cycle_preset(instance, result, field)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'reset_dynamic_preset' and color_fields[field] then
    local ok, err = dynamic_editor.reset_preset(instance, result, field)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'adjust_dynamic_duration' and color_fields[field] then
    local ok, err = dynamic_editor.adjust_duration(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'set_dynamic_loop' and color_fields[field] then
    local ok, err = dynamic_editor.set_loop(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'set_dynamic_phase' and color_fields[field] then
    local ok, err = dynamic_editor.set_phase(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'set_dynamic_raw_json' and color_fields[field] then
    local ok, err = dynamic_editor.set_raw_json(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'open_dynamic_raw_json' and color_fields[field] then
    require('hlcraft.ui.raw_dynamic').open(instance, result, field)
    return true, nil
  end
  if action == 'set_group' and ui_fields.detail_kinds[field] == 'group' then
    local ok, err = group_editor.set(instance, result, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'set_blend' and ui_fields.detail_kinds[field] == 'blend' then
    local ok, err = blend_editor.set(instance, result, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'adjust_blend' and ui_fields.detail_kinds[field] == 'blend' then
    local ok, err = blend_editor.adjust(instance, result, ...)
    return finish_edit(instance, ok, err, field)
  end
  return false, ('unsupported field editor action: %s'):format(tostring(action))
end

return M
