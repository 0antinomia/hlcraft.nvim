local search_scene = require('hlcraft.ui.scene.search')
local session = require('hlcraft.ui.session')
local style_editor = require('hlcraft.ui.editor.style')
local highlight_names = require('hlcraft.core.highlight_names')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local rows = require('hlcraft.ui.scene.rows')
local unsaved_prompt = require('hlcraft.ui.scene.unsaved_prompt')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('detail scene requires an instance', 3)
  end
  return instance.state
end

local function field_editor_state(state)
  if type(state.field_editor) ~= 'table' then
    error('detail scene field editor state must be a table', 3)
  end
  return state.field_editor
end

local function result_list(state)
  return tables.assert_sequence(state.results, 'detail scene results', 3)
end

local function result_lines(state)
  if type(state.geometry) ~= 'table' then
    error('detail geometry must be a table', 3)
  end
  local lines = state.geometry.result_lines
  if type(lines) ~= 'table' then
    error('detail geometry result_lines must be a table', 3)
  end
  return lines
end

local function restore_search_scene(instance)
  require('hlcraft.ui.scene').set(instance, 'search')
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

local function positive_integer(value, label)
  if type(value) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  if not numbers.is_integer(value, 1) then
    error(('%s must be a positive finite integer'):format(label), 3)
  end
  return value
end

local function optional_boolean(value, label)
  if value ~= nil and type(value) ~= 'boolean' then
    error(('%s must be boolean or nil'):format(label), 3)
  end
  return value == true
end

local function assert_name(name)
  return highlight_names.assert(name, 'detail result name', 3)
end

local function assert_action(action)
  if type(action) ~= 'string' or action == '' then
    error('detail action must be a non-empty string', 3)
  end
  return action
end

local function assert_rerender(instance)
  if type(instance.rerender) ~= 'function' then
    error('detail scene requires a rerender callback', 3)
  end
end

local function snapshot_detail_state(state, field_editor)
  return {
    detail_index = state.detail_index,
    field = field_editor.field,
    geometry = vim.deepcopy(state.geometry),
    list_cursor = state.list_cursor,
    results = vim.deepcopy(state.results),
    scene = vim.deepcopy(state.scene),
  }
end

local function restore_detail_state(state, field_editor, snapshot)
  state.detail_index = snapshot.detail_index
  field_editor.field = snapshot.field
  state.geometry = snapshot.geometry
  state.list_cursor = snapshot.list_cursor
  state.results = snapshot.results
  state.scene = snapshot.scene
end

local function append_rollback_error(err, rollback_err)
  if rollback_err == nil then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, tostring(rollback_err))
end

local function rerender_restored_state(instance, state, field_editor, snapshot)
  local ok, err = xpcall(function()
    instance:rerender()
  end, debug.traceback)
  if not ok then
    restore_detail_state(state, field_editor, snapshot)
    return false, err
  end
  return true, nil
end

function M.enter(instance, opts)
  local state = instance_state(instance)
  opts = optional_table(opts, 'detail entry')
  for key in pairs(opts) do
    if key ~= 'index' then
      error(('unknown detail entry option: %s'):format(tostring(key)), 3)
    end
  end
  if opts.index == nil then
    error('detail entry requires an index', 3)
  end
  state.detail_index = positive_integer(opts.index, 'detail entry index')
end

function M.render(instance)
  instance_state(instance)
  search_scene.update_results(instance)
  require('hlcraft.ui.render.detail').render(instance)
end

function M.back(instance)
  instance_state(instance)
  M.close(instance)
  return true, nil
end

--- Get the highlight result currently shown in detail view
--- @param instance table The Instance object holding UI state
--- @return table|nil Result entry, or nil if no detail is open
function M.current_result(instance)
  local state = instance_state(instance)
  local index = state.detail_index
  if not index then
    return nil
  end
  index = positive_integer(index, 'detail index')
  return result_list(state)[index]
end

--- Re-render and navigate to a named result, optionally reopening detail view
--- @param instance table The Instance object holding UI state
--- @param name string Highlight group name to navigate to
--- @param reopen_detail boolean Whether to reopen the detail view for this result
--- @return nil
function M.refresh(instance, name, reopen_detail)
  local state = instance_state(instance)
  local field_editor = field_editor_state(state)
  name = assert_name(name)
  reopen_detail = optional_boolean(reopen_detail, 'detail reopen flag')
  assert_rerender(instance)

  local snapshot = snapshot_detail_state(state, field_editor)
  local rendered = false
  local ok, err = xpcall(function()
    local active_field = field_editor.field
    rendered = true
    instance:rerender()
    local results = result_list(state)
    for index, result in ipairs(results) do
      if result.name == name then
        state.list_cursor = index
        if reopen_detail then
          state.detail_index = index
          field_editor.field = active_field
          instance:rerender()
        end
        return
      end
    end

    if reopen_detail then
      local cursor = positive_integer(state.list_cursor, 'detail list cursor')
      state.detail_index = nil
      field_editor.field = nil
      state.list_cursor = math.min(math.max(cursor, 1), math.max(#results, 1))
      restore_search_scene(instance)
      instance:rerender()
    end
  end, debug.traceback)
  if not ok then
    restore_detail_state(state, field_editor, snapshot)
    if rendered then
      local restored, restore_err = rerender_restored_state(instance, state, field_editor, snapshot)
      if not restored then
        err = append_rollback_error(err, restore_err)
      end
    end
    error(err, 0)
  end
end

--- Close and delete the unsaved-changes prompt window and buffer
--- @param instance table The Instance object holding UI state
--- @return nil
function M.close_unsaved_prompt(instance)
  instance_state(instance)
  local closed, err = unsaved_prompt.close(instance)
  if not closed then
    error(('failed to close unsaved prompt: %s'):format(tostring(err)), 2)
  end
end

--- Close the detail view without checking for unsaved changes
--- @param instance table The Instance object holding UI state
--- @return nil
function M.force_close(instance)
  local state = instance_state(instance)
  local field_editor = field_editor_state(state)
  assert_rerender(instance)
  local snapshot = snapshot_detail_state(state, field_editor)
  local rendered = false
  local ok, err = xpcall(function()
    state.detail_index = nil
    field_editor.field = nil
    restore_search_scene(instance)
    rendered = true
    instance:rerender()
    local win = window.get_win(instance)
    if not window.is_valid_win(win) then
      M.close_unsaved_prompt(instance)
      return
    end
    for line, index in pairs(result_lines(state)) do
      if index == state.list_cursor then
        vim.api.nvim_win_set_cursor(win, { line, 0 })
        break
      end
    end
    M.close_unsaved_prompt(instance)
  end, debug.traceback)
  if not ok then
    restore_detail_state(state, field_editor, snapshot)
    if rendered then
      local restored, restore_err = rerender_restored_state(instance, state, field_editor, snapshot)
      if not restored then
        err = append_rollback_error(err, restore_err)
      end
    end
    error(err, 0)
  end
end

--- Open a confirmation prompt for closing a dirty detail view
--- @param instance table The Instance object holding UI state
--- @param name string Highlight group name
--- @return nil
function M.open_unsaved_prompt(instance, name)
  instance_state(instance)
  name = assert_name(name)
  unsaved_prompt.open(instance, name, function()
    M.force_close(instance)
  end)
end

--- Close the detail view and return to the result list, restoring cursor position
--- @param instance table The Instance object holding UI state
--- @return nil
function M.close(instance)
  local state = instance_state(instance)
  if not state.detail_index then
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
  instance_state(instance)
  return rows.detail_menu_at_cursor(instance)
end

function M.activate(instance)
  assert_rerender(instance)
  local state = instance_state(instance)
  local field_editor = field_editor_state(state)
  local row = M.row_at_cursor(instance)
  local result = M.current_result(instance)
  if not row or not result then
    return false, nil
  end
  if row.kind == 'boolean' then
    return style_editor.toggle(instance, result, row.key)
  end
  if row.kind == 'group' or row.kind == 'color' or row.kind == 'blend' then
    local snapshot = snapshot_detail_state(state, field_editor)
    local rendered = false
    local ok, err = xpcall(function()
      local scene_ok, scene_err = require('hlcraft.ui.scene').set(instance, 'field_editor', {
        field = row.key,
      })
      if not scene_ok then
        error(scene_err or 'failed to open field editor scene', 0)
      end
      rendered = true
      instance:rerender()
    end, debug.traceback)
    if not ok then
      restore_detail_state(state, field_editor, snapshot)
      if rendered then
        local restored, restore_err = rerender_restored_state(instance, state, field_editor, snapshot)
        if not restored then
          err = append_rollback_error(err, restore_err)
        end
      end
      error(err, 0)
    end
    return true, nil
  end
  return false, nil
end

function M.handle(instance, action)
  instance_state(instance)
  action = assert_action(action)
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
