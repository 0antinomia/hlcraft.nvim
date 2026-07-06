local window = require('hlcraft.ui.workspace.window')
local numbers = require('hlcraft.core.number')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('scene rows require an instance', 3)
  end
  return instance.state
end

local function geometry_table(instance, key)
  local state = instance_state(instance)
  if type(state.geometry) ~= 'table' then
    error('scene rows geometry must be a table', 3)
  end
  local rows = state.geometry[key]
  if type(rows) ~= 'table' then
    error(('scene rows geometry %s must be a table'):format(key), 3)
  end
  return rows
end

local function assert_rows(rows)
  if type(rows) ~= 'table' then
    error('scene rows must be a table', 3)
  end
  return rows
end

local function assert_line(line, label)
  if type(line) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  if not numbers.is_integer(line, 1) then
    error(('%s must be a positive finite integer'):format(label), 3)
  end
  return line
end

local function row_with_key(row, key)
  if type(row) ~= 'table' then
    error('scene row must be a table', 3)
  end
  assert_line(row.line, 'scene row line')
  local result = vim.tbl_extend('force', {}, row)
  result.key = result.key or key
  return result
end

function M.cursor_line(instance)
  instance_state(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end
  return vim.api.nvim_win_get_cursor(win)[1]
end

function M.find_by_line(rows, line)
  if line == nil then
    return nil
  end
  line = assert_line(line, 'scene target line')

  for key, row in pairs(assert_rows(rows)) do
    if row.line == line then
      return row_with_key(row, key)
    end
  end
end

function M.at_cursor(instance, rows)
  return M.find_by_line(rows, M.cursor_line(instance))
end

function M.detail_menu_at_cursor(instance)
  return M.at_cursor(instance, geometry_table(instance, 'detail_menu'))
end

function M.editor_row_at_cursor(instance)
  return M.at_cursor(instance, geometry_table(instance, 'editor_rows'))
end

return M
