local detail_scene = require('hlcraft.ui.scene.detail')
local style_editor = require('hlcraft.ui.editor.style')
local field_editor_actions = require('hlcraft.ui.scene.field_editor_actions')
local session = require('hlcraft.ui.session')
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
