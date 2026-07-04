local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local navigation = require('hlcraft.ui.navigation')
local search_model = require('hlcraft.ui.search_model')
local ui_fields = require('hlcraft.ui.fields')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function result_lines(instance)
  local lines = instance.state.geometry.result_lines
  if type(lines) ~= 'table' then
    error('search geometry result_lines must be a table', 3)
  end
  return lines
end

function M.enter(instance)
  instance.state.scene.name = 'search'
end

function M.render(instance)
  M.update_results(instance)
  require('hlcraft.ui.render.search').render(instance)
end

function M.back(instance)
  lifecycle.close(instance)
  return true, nil
end

--- Get the empty-state message based on current query filters
--- @param instance table The Instance object holding UI state
--- @return string Human-readable message explaining why results are empty
function M.empty_message(instance)
  return search_model.empty_message(instance.state.name_query, instance.state.color_query)
end

--- Run search queries and update instance.state.results with matching highlight groups
--- @param instance table The Instance object holding UI state
--- @return nil
function M.update_results(instance)
  instance.state.results = search_model.results(instance.state.name_query, instance.state.color_query)
  if instance.state.detail_index == nil then
    instance.state.list_cursor = math.min(math.max(instance.state.list_cursor, 1), math.max(#instance.state.results, 1))
  end
end

--- Get the result rows as a sorted list of {line, index} entries
--- @param instance table The Instance object holding UI state
--- @return table[] Sorted array of {line=number, index=number} entries
function M.rows(instance)
  local rows = {}
  for line_nr, result_index in pairs(result_lines(instance)) do
    rows[#rows + 1] = { line = line_nr, index = result_index }
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
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(win)[1]
  local index = result_lines(instance)[row]
  if not index then
    return nil
  end
  return { row = row, index = index, result = instance.state.results[index] }
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
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end
  local row = vim.api.nvim_win_get_cursor(win)[1]
  local index = instance.state.geometry.result_lines[row]
  if not index then
    return false
  end
  instance.state.detail_index = index
  instance.state.field_editor.field = nil
  require('hlcraft.ui.scene').set(instance, 'detail', { index = index })
  instance:rerender()
  local first_key = ui_fields.detail_order[1]
  local first_row = first_key and instance.state.geometry.detail_menu[first_key]
  if first_row then
    navigation.jump_to_row(instance, first_row.line, false)
  end
  return true
end

function M.handle(instance, action)
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
    instance:rerender()
    if #instance.state.results > 0 then
      local target_line = nil
      for _, entry in ipairs(M.rows(instance)) do
        if entry.index == instance.state.list_cursor then
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
