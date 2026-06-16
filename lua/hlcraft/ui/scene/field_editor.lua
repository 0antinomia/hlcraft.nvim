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

local function current_dynamic(result, key)
  return session.dynamic_value(result.name, key)
end

local function selected_palette_index(instance, dynamic)
  local editor_row = M.editor_row_at_cursor(instance)
  local row_key = editor_row and editor_row.key or ''
  local index = tonumber(tostring(row_key):match('^dynamic_palette:(%d+)$'))
  local count = type(dynamic.palette) == 'table' and #dynamic.palette or 0
  if index and dynamic.palette and dynamic.palette[index] then
    return index
  end
  if count == 0 then
    return 1
  end

  local stored = tonumber(instance.state.field_editor.palette_index) or 1
  return math.max(1, math.min(count, stored))
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

local function jump_to_palette_index(instance, index)
  local row = instance.state.geometry.editor_rows[('dynamic_palette:%d'):format(index)]
  local win = window.get_win(instance)
  if row and window.is_valid_win(win) then
    pcall(vim.api.nvim_win_set_cursor, win, { row.line, 0 })
  end
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
  local editor_row = M.editor_row_at_cursor(instance)
  local row_key = editor_row and editor_row.key or ''
  return tostring(row_key):match('^dynamic_param:(%w+)$')
end

M.selected_dynamic_param_name = M.selected_param_name

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

  local result = M.current_result(instance)
  local field = M.current_field(instance)
  if not result or not field then
    return false, 'No field editor is active'
  end

  if action == 'set_color' and color_fields[field] then
    if current_dynamic(result, field) then
      return false, 'Static color controls are disabled in dynamic mode'
    end
    local ok, err = color_editor.set(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'adjust_color' and color_fields[field] then
    if current_dynamic(result, field) then
      return false, 'Static color controls are disabled in dynamic mode'
    end
    local ok, err = color_editor.adjust(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'toggle_dynamic' and color_fields[field] then
    local ok, err = dynamic_editor.toggle(instance, result, field)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'cycle_dynamic_mode' and color_fields[field] then
    local ok, err = dynamic_editor.cycle_mode(instance, result, field)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'adjust_dynamic_speed' and color_fields[field] then
    local ok, err = dynamic_editor.adjust_speed(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'set_dynamic_param' and color_fields[field] then
    local ok, err = dynamic_editor.set_param(instance, result, field, ...)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'adjust_dynamic_param' and color_fields[field] then
    local name, delta = ...
    local param_name = name or M.selected_param_name(instance) or 'min'
    local ok, err = dynamic_editor.adjust_param(instance, result, field, param_name, delta)
    return finish_edit(instance, ok, err, field)
  end
  if action == 'select_dynamic_palette' and color_fields[field] then
    local dynamic = current_dynamic(result, field) or {}
    local current_index = selected_palette_index(instance, dynamic)
    local ok, next_index_or_err = dynamic_editor.select_palette(instance, result, field, current_index, ...)
    if not ok then
      return false, next_index_or_err
    end
    instance.state.field_editor.palette_index = next_index_or_err
    instance:rerender()
    jump_to_palette_index(instance, next_index_or_err)
    return true, nil
  end
  if action == 'add_dynamic_palette_color' and color_fields[field] then
    local dynamic = current_dynamic(result, field) or {}
    local index = selected_palette_index(instance, dynamic)
    local ok, err, next_index = dynamic_editor.add_palette_color(instance, result, field, index)
    local finished_ok, finished_err = finish_edit(instance, ok, err, field)
    if finished_ok then
      instance.state.field_editor.palette_index = next_index
      jump_to_palette_index(instance, next_index)
    end
    return finished_ok, finished_err
  end
  if action == 'delete_dynamic_palette_color' and color_fields[field] then
    local dynamic = current_dynamic(result, field) or {}
    local index = selected_palette_index(instance, dynamic)
    local ok, err, next_index = dynamic_editor.delete_palette_color(instance, result, field, index)
    local finished_ok, finished_err = finish_edit(instance, ok, err, field)
    if finished_ok then
      instance.state.field_editor.palette_index = next_index
      jump_to_palette_index(instance, next_index)
    end
    return finished_ok, finished_err
  end
  if action == 'set_dynamic_palette_color' and color_fields[field] then
    local dynamic = current_dynamic(result, field) or {}
    local index = selected_palette_index(instance, dynamic)
    local ok, err, next_index = dynamic_editor.set_palette_color(instance, result, field, index, ...)
    local finished_ok, finished_err = finish_edit(instance, ok, err, field)
    if finished_ok then
      instance.state.field_editor.palette_index = next_index
      jump_to_palette_index(instance, next_index)
    end
    return finished_ok, finished_err
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
