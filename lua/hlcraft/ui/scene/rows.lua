local window = require('hlcraft.ui.workspace.window')

local M = {}

local function assert_rows(rows)
  if type(rows) ~= 'table' then
    error('scene rows must be a table', 3)
  end
  return rows
end

local function row_with_key(row, key)
  local result = vim.tbl_extend('force', {}, row)
  result.key = result.key or key
  return result
end

function M.cursor_line(instance)
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
  return M.at_cursor(instance, instance.state.geometry.detail_menu)
end

function M.editor_row_at_cursor(instance)
  return M.at_cursor(instance, instance.state.geometry.editor_rows)
end

return M
