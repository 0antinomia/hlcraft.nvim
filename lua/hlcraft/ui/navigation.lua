local window = require('hlcraft.ui.workspace.window')
local buffer_lines = require('hlcraft.ui.buffer_lines')
local numbers = require('hlcraft.core.number')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('navigation requires an instance', 3)
  end
  return instance.state
end

local function assert_row1(row1, label)
  if type(row1) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  if not numbers.is_finite(row1) or math.floor(row1) ~= row1 or row1 < 1 then
    error(('%s must be a positive finite integer'):format(label), 3)
  end
  return row1
end

local function assert_step(step)
  if type(step) ~= 'number' then
    error('navigation step must be a number', 3)
  end
  if not numbers.is_finite(step) or math.floor(step) ~= step then
    error('navigation step must be a finite integer', 3)
  end
  return step
end

local function assert_insert(insert)
  if type(insert) ~= 'boolean' then
    error('navigation insert flag must be boolean', 3)
  end
  return insert
end

local function geometry_table(state, key)
  if type(state.geometry) ~= 'table' then
    error('navigation geometry must be a table', 3)
  end
  local value = state.geometry[key]
  if type(value) ~= 'table' then
    error(('navigation geometry %s must be a table'):format(key), 3)
  end
  return value
end

local function append_row(rows, row, label)
  rows[#rows + 1] = assert_row1(row, label)
end

--- Get sorted list of row numbers where the cursor is allowed to land
--- @param instance table The Instance object holding UI state
--- @return number[] Sorted list of allowed 1-based row numbers
function M.allowed_rows(instance)
  local state = instance_state(instance)
  local rows = {}
  for _, field in ipairs(geometry_table(state, 'inputs')) do
    if not state.detail_index then
      append_row(rows, field.line, 'navigation input row')
    end
  end
  if state.detail_index then
    for _, row in pairs(geometry_table(state, 'detail_menu')) do
      append_row(rows, row.line, 'navigation detail row')
    end
    for _, row in pairs(geometry_table(state, 'editor_rows')) do
      append_row(rows, row.line, 'navigation editor row')
    end
  else
    for line_nr in pairs(geometry_table(state, 'result_lines')) do
      append_row(rows, line_nr, 'navigation result row')
    end
  end
  table.sort(rows)
  return rows
end

--- Find the closest allowed row to the given row number
--- @param instance table The Instance object holding UI state
--- @param row number 1-based row number to search near
--- @return number|nil Nearest allowed row, or nil if no allowed rows
function M.nearest_allowed_row(instance, row)
  row = assert_row1(row, 'navigation row')
  local rows = M.allowed_rows(instance)
  if #rows == 0 then
    return nil
  end
  local nearest = rows[1]
  local best_distance = math.abs(row - nearest)
  for _, candidate in ipairs(rows) do
    local distance = math.abs(row - candidate)
    if distance < best_distance or (distance == best_distance and candidate < nearest) then
      nearest = candidate
      best_distance = distance
    end
  end
  return nearest
end

--- Get the allowed row at offset `step` from the given row
--- @param instance table The Instance object holding UI state
--- @param row number Current 1-based row number
--- @param step integer Direction and distance (+1 forward, -1 backward)
--- @return number|nil Adjacent allowed row, clamped to bounds
function M.adjacent_allowed_row(instance, row, step)
  row = assert_row1(row, 'navigation row')
  step = assert_step(step)
  local rows = M.allowed_rows(instance)
  if #rows == 0 then
    return nil
  end

  for index, candidate in ipairs(rows) do
    if candidate == row then
      local next_index = index + step
      if next_index < 1 then
        return rows[1]
      end
      if next_index > #rows then
        return rows[#rows]
      end
      return rows[next_index]
    end
  end

  return M.nearest_allowed_row(instance, row)
end

--- Move cursor to the nearest allowed row if it is on a disallowed row
--- @param instance table The Instance object holding UI state
--- @return boolean moved True when the cursor was moved
function M.clamp_cursor(instance)
  local state = instance_state(instance)
  if state.clamping_cursor then
    return false
  end
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local row, col = cursor[1], cursor[2]
  local target_row = M.nearest_allowed_row(instance, row)
  if not target_row or target_row == row then
    return false
  end

  state.clamping_cursor = true
  local ok = pcall(function()
    local line = buffer_lines.line(state.buf, target_row - 1, 'navigation target')
    vim.api.nvim_win_set_cursor(win, { target_row, math.min(col, #line) })
  end)
  state.clamping_cursor = false
  return ok
end

--- Move cursor to a specific row and optionally enter insert mode
--- @param instance table The Instance object holding UI state
--- @param row1 number 1-based target row number
--- @param insert boolean Whether to enter insert mode after jumping
--- @return boolean moved True when the cursor was moved
function M.jump_to_row(instance, row1, insert)
  instance_state(instance)
  row1 = assert_row1(row1, 'navigation target row')
  insert = assert_insert(insert)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { row1, 0 })
  if insert then
    vim.cmd('startinsert!')
  end
  return true
end

--- Move the cursor by `step` rows through allowed rows only
--- @param instance table The Instance object holding UI state
--- @param step integer Number of rows to move (+1 down, -1 up)
--- @return boolean moved True when the cursor was moved
function M.move_interactive(instance, step)
  instance_state(instance)
  step = assert_step(step)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end
  local current = vim.api.nvim_win_get_cursor(win)
  local target_row = M.adjacent_allowed_row(instance, current[1], step)
  if target_row then
    return M.jump_to_row(instance, target_row, false)
  end
  return false
end

return M
