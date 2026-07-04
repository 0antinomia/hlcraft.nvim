local search_scene = require('hlcraft.ui.scene.search')
local session = require('hlcraft.ui.session')
local style_editor = require('hlcraft.ui.editor.style')
local ui_fields = require('hlcraft.ui.fields')
local rows = require('hlcraft.ui.scene.rows')
local unsaved_prompt = require('hlcraft.ui.scene.unsaved_prompt')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function restore_search_scene(instance)
  require('hlcraft.ui.scene').set(instance, 'search')
end

function M.enter(instance, opts)
  instance.state.detail_index = opts and opts.index or instance.state.detail_index
end

function M.render(instance)
  search_scene.update_results(instance)
  require('hlcraft.ui.render.detail').render(instance)
end

function M.back(instance)
  M.close(instance)
  return true, nil
end

--- Get the highlight result currently shown in detail view
--- @param instance table The Instance object holding UI state
--- @return table|nil Result entry, or nil if no detail is open
function M.current_result(instance)
  local index = instance.state.detail_index
  if not index then
    return nil
  end
  return instance.state.results[index]
end

--- Re-render and navigate to a named result, optionally reopening detail view
--- @param instance table The Instance object holding UI state
--- @param name string Highlight group name to navigate to
--- @param reopen_detail boolean Whether to reopen the detail view for this result
--- @return nil
function M.refresh(instance, name, reopen_detail)
  local active_field = instance.state.field_editor and instance.state.field_editor.field or nil
  instance:rerender()
  for index, result in ipairs(instance.state.results) do
    if result.name == name then
      instance.state.list_cursor = index
      if reopen_detail then
        instance.state.detail_index = index
        instance.state.field_editor.field = active_field
        instance:rerender()
      end
      return
    end
  end

  if reopen_detail then
    instance.state.detail_index = nil
    instance.state.field_editor.field = nil
    instance.state.list_cursor = math.min(math.max(instance.state.list_cursor, 1), math.max(#instance.state.results, 1))
    restore_search_scene(instance)
    instance:rerender()
  end
end

--- Close and delete the unsaved-changes prompt window and buffer
--- @param instance table The Instance object holding UI state
--- @return nil
function M.close_unsaved_prompt(instance)
  unsaved_prompt.close(instance)
end

--- Close the detail view without checking for unsaved changes
--- @param instance table The Instance object holding UI state
--- @return nil
function M.force_close(instance)
  M.close_unsaved_prompt(instance)
  instance.state.detail_index = nil
  instance.state.field_editor.field = nil
  restore_search_scene(instance)
  instance:rerender()
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return
  end
  for line, index in pairs(instance.state.geometry.result_lines or {}) do
    if index == instance.state.list_cursor then
      vim.api.nvim_win_set_cursor(win, { line, 0 })
      break
    end
  end
end

--- Open a confirmation prompt for closing a dirty detail view
--- @param instance table The Instance object holding UI state
--- @param name string Highlight group name
--- @return nil
function M.open_unsaved_prompt(instance, name)
  unsaved_prompt.open(instance, name, function()
    M.force_close(instance)
  end)
end

--- Close the detail view and return to the result list, restoring cursor position
--- @param instance table The Instance object holding UI state
--- @return nil
function M.close(instance)
  if not instance.state.detail_index then
    return
  end
  local result = M.current_result(instance)
  if result and session.is_dirty(result.name) then
    M.open_unsaved_prompt(instance, result.name)
    return
  end
  M.force_close(instance)
end

function M.row_at_cursor(instance)
  return rows.detail_menu_at_cursor(instance)
end

function M.activate(instance)
  local row = M.row_at_cursor(instance)
  local result = M.current_result(instance)
  if not row or not result then
    return false, nil
  end
  if row.kind == 'boolean' then
    return style_editor.toggle(instance, result, row.key)
  end
  if row.kind == 'group' or row.kind == 'color' or row.kind == 'blend' then
    require('hlcraft.ui.scene').set(instance, 'field_editor', {
      field = row.key,
      kind = ui_fields.detail_kinds[row.key],
    })
    instance:rerender()
    return true, nil
  end
  return false, nil
end

function M.handle(instance, action)
  if action == 'activate' then
    return M.activate(instance)
  end
  if action == 'save' then
    local result = M.current_result(instance)
    if not result then
      return false, nil
    end
    return session.save(instance, result.name)
  end
  return false, ('unsupported detail action: %s'):format(tostring(action))
end

return M
