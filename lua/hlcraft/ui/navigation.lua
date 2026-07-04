local window = require('hlcraft.ui.workspace.window')
local buffer_lines = require('hlcraft.ui.buffer_lines')

local M = {}

local function geometry_table(instance, key)
  local value = instance.state.geometry[key]
  if type(value) ~= 'table' then
    error(('navigation geometry %s must be a table'):format(key), 3)
  end
  return value
end

--- Get sorted list of row numbers where the cursor is allowed to land
--- @param instance table The Instance object holding UI state
--- @return number[] Sorted list of allowed 1-based row numbers
function M.allowed_rows(instance)
  local rows = {}
  for _, field in ipairs(geometry_table(instance, 'inputs')) do
    if not instance.state.detail_index then
      rows[#rows + 1] = field.line
    end
  end
  if instance.state.detail_index then
    for _, row in pairs(geometry_table(instance, 'detail_menu')) do
      rows[#rows + 1] = row.line
    end
    for _, row in pairs(geometry_table(instance, 'editor_rows')) do
      rows[#rows + 1] = row.line
    end
  else
    for line_nr in pairs(geometry_table(instance, 'result_lines')) do
      rows[#rows + 1] = line_nr
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
  if instance.state.clamping_cursor then
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

  instance.state.clamping_cursor = true
  local ok = pcall(function()
    local line = buffer_lines.line(instance.state.buf, target_row - 1, 'navigation target')
    vim.api.nvim_win_set_cursor(win, { target_row, math.min(col, #line) })
  end)
  instance.state.clamping_cursor = false
  return ok
end

--- Move cursor to a specific row and optionally enter insert mode
--- @param instance table The Instance object holding UI state
--- @param row1 number 1-based target row number
--- @param insert boolean Whether to enter insert mode after jumping
--- @return boolean moved True when the cursor was moved
function M.jump_to_row(instance, row1, insert)
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
