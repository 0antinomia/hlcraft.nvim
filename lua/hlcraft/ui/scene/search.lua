local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local navigation = require('hlcraft.ui.navigation')
local search_model = require('hlcraft.ui.search_model')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local ui_fields = require('hlcraft.ui.fields')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('search scene requires an instance', 3)
  end
  return instance.state
end

local function scene_state(state)
  if type(state.scene) ~= 'table' then
    error('search scene state must be a table', 3)
  end
  return state.scene
end

local function field_editor_state(state)
  if type(state.field_editor) ~= 'table' then
    error('search scene field editor state must be a table', 3)
  end
  return state.field_editor
end

local function geometry_table(state)
  if type(state.geometry) ~= 'table' then
    error('search geometry must be a table', 3)
  end
  return state.geometry
end

local function result_list(state)
  return tables.assert_sequence(state.results, 'search scene results', 3)
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

local function assert_step(step)
  if type(step) ~= 'number' then
    error('search navigation step must be a number', 3)
  end
  if not numbers.is_integer(step) then
    error('search navigation step must be a finite integer', 3)
  end
  return step
end

local function assert_action(action)
  if type(action) ~= 'string' or action == '' then
    error('search action must be a non-empty string', 3)
  end
  return action
end

local function assert_rerender(instance)
  if type(instance.rerender) ~= 'function' then
    error('search scene requires a rerender callback', 3)
  end
end

local function result_lines(state)
  local lines = geometry_table(state).result_lines
  if type(lines) ~= 'table' then
    error('search geometry result_lines must be a table', 3)
  end
  return lines
end

local function result_at(results, index, label)
  local result = results[index]
  if result == nil then
    error(('%s must reference an existing search result'):format(label), 3)
  end
  return result
end

local function snapshot_detail_open_state(state, field_editor)
  return {
    detail_index = state.detail_index,
    field = field_editor.field,
    geometry = vim.deepcopy(state.geometry),
    list_cursor = state.list_cursor,
    results = vim.deepcopy(state.results),
    scene = vim.deepcopy(state.scene),
  }
end

local function restore_detail_open_state(state, field_editor, snapshot)
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

local function rerender_restored_detail_open(instance, state, field_editor, snapshot)
  local ok, err = xpcall(function()
    instance:rerender()
  end, debug.traceback)
  if not ok then
    restore_detail_open_state(state, field_editor, snapshot)
    return false, err
  end
  return true, nil
end

function M.enter(instance)
  scene_state(instance_state(instance)).name = 'search'
end

function M.render(instance)
  instance_state(instance)
  M.update_results(instance)
  require('hlcraft.ui.render.search').render(instance)
end

function M.back(instance)
  instance_state(instance)
  if lifecycle.close(instance) == false then
    return false, nil
  end
  return true, nil
end

--- Get the empty-state message based on current query filters
--- @param instance table The Instance object holding UI state
--- @return string Human-readable message explaining why results are empty
function M.empty_message(instance)
  local state = instance_state(instance)
  return search_model.empty_message(state.name_query, state.color_query)
end

--- Run search queries and update instance.state.results with matching highlight groups
--- @param instance table The Instance object holding UI state
--- @return nil
function M.update_results(instance)
  local state = instance_state(instance)
  local cursor = 1
  if state.detail_index == nil then
    cursor = positive_integer(state.list_cursor, 'search list cursor')
  end
  state.results = search_model.results(state.name_query, state.color_query)
  if state.detail_index == nil then
    state.list_cursor = math.min(math.max(cursor, 1), math.max(#state.results, 1))
  end
end

--- Get the result rows as a sorted list of {line, index} entries
--- @param instance table The Instance object holding UI state
--- @return table[] Sorted array of {line=number, index=number} entries
function M.rows(instance)
  local state = instance_state(instance)
  local results = result_list(state)
  local rows = {}
  for line_nr, result_index in pairs(result_lines(state)) do
    local index = positive_integer(result_index, 'search result index')
    result_at(results, index, 'search result index')
    rows[#rows + 1] = {
      line = positive_integer(line_nr, 'search result line'),
      index = index,
    }
  end
  table.sort(rows, function(a, b)
    return a.line < b.line
  end)
  return rows
end

--- Get the result entry at the current cursor position
--- @param instance table The Instance object holding UI state
--- @return table|nil Entry with row, index, and result keys, or nil
function M.current_entry(instance)
  local state = instance_state(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(win)[1]
  local index = result_lines(state)[row]
  if not index then
    return nil
  end
  index = positive_integer(index, 'search result index')
  return { row = row, index = index, result = result_at(result_list(state), index, 'search result index') }
end

--- Check if the cursor is on a result row
--- @param instance table The Instance object holding UI state
--- @return boolean True if cursor is on a result row
function M.is_on_row(instance)
  return M.current_entry(instance) ~= nil
end

--- Move the cursor by `step` result rows (jump between result entries)
--- @param instance table The Instance object holding UI state
--- @param step integer Number of entries to jump (+1 forward, -1 backward)
--- @return boolean moved True when the cursor was moved
function M.goto_offset(instance, step)
  step = assert_step(step)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end

  local rows = M.rows(instance)
  if #rows == 0 then
    return false
  end

  local current_row = vim.api.nvim_win_get_cursor(win)[1]
  for idx, entry in ipairs(rows) do
    if entry.line == current_row then
      local target = rows[math.max(1, math.min(#rows, idx + step))]
      return navigation.jump_to_row(instance, target.line, false)
    end
  end

  return navigation.jump_to_row(instance, rows[1].line, false)
end

--- Move the cursor to the first result row
--- @param instance table The Instance object holding UI state
--- @return boolean moved True when the cursor was moved
function M.goto_first(instance)
  local rows = M.rows(instance)
  if #rows > 0 then
    return navigation.jump_to_row(instance, rows[1].line, false)
  end
  return false
end

--- Open the detail view for the result at the current cursor position
--- @param instance table The Instance object holding UI state
--- @return boolean opened True when the detail scene was opened
function M.open_detail(instance)
  local state = instance_state(instance)
  local field_editor = field_editor_state(state)
  assert_rerender(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end
  local row = vim.api.nvim_win_get_cursor(win)[1]
  local index = result_lines(state)[row]
  if not index then
    return false
  end
  index = positive_integer(index, 'search result index')
  result_at(result_list(state), index, 'search result index')
  local snapshot = snapshot_detail_open_state(state, field_editor)
  local rendered = false
  local ok, err = xpcall(function()
    state.list_cursor = index
    state.detail_index = index
    field_editor.field = nil
    local scene_ok, scene_err = require('hlcraft.ui.scene').set(instance, 'detail', { index = index })
    if not scene_ok then
      error(scene_err or 'failed to open detail scene', 0)
    end
    rendered = true
    instance:rerender()
    local first_key = ui_fields.detail_order[1]
    local rendered_detail_menu = geometry_table(state).detail_menu
    if type(rendered_detail_menu) ~= 'table' then
      error('search rendered detail_menu must be a table', 3)
    end
    local first_row = first_key and rendered_detail_menu[first_key]
    if first_row then
      navigation.jump_to_row(instance, first_row.line, false)
    end
  end, debug.traceback)
  if not ok then
    restore_detail_open_state(state, field_editor, snapshot)
    if rendered then
      local restored, restore_err = rerender_restored_detail_open(instance, state, field_editor, snapshot)
      if not restored then
        err = append_rollback_error(err, restore_err)
      end
    end
    error(err, 0)
  end
  return true
end

function M.handle(instance, action)
  local state = instance_state(instance)
  action = assert_action(action)
  if action == 'activate' then
    local win = window.get_win(instance)
    if not window.is_valid_win(win) then
      return false, nil
    end
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local area = buffer_fields.current_area(instance, row)
    if area == 'results' then
      return M.open_detail(instance), nil
    end
    if vim.fn.mode():lower():find('i') then
      vim.cmd('stopinsert')
    end
    buffer_fields.sync_queries(instance)
    assert_rerender(instance)
    instance:rerender()
    local results = result_list(state)
    if #results > 0 then
      local target_line = nil
      for _, entry in ipairs(M.rows(instance)) do
        if entry.index == state.list_cursor then
          target_line = entry.line
          break
        end
      end
      if target_line then
        navigation.jump_to_row(instance, target_line, false)
      else
        M.goto_first(instance)
      end
    end
    return true, nil
  end
  if action == 'open_detail' then
    return M.open_detail(instance), nil
  end
  if action == 'next_result' then
    return M.goto_offset(instance, 1), nil
  end
  if action == 'prev_result' then
    return M.goto_offset(instance, -1), nil
  end
  if action == 'first_result' then
    return M.goto_first(instance), nil
  end
  return false, ('unsupported search action: %s'):format(tostring(action))
end

return M
