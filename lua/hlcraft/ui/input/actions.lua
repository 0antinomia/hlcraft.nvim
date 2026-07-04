local input_model = require('hlcraft.ui.input.model')
local paste_plan = require('hlcraft.ui.input.paste_plan')
local input_sequence = require('hlcraft.ui.input.sequence')
local navigation = require('hlcraft.ui.navigation')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function get_search_scene()
  return require('hlcraft.ui.scene.search')
end

local function feed_key(key)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'n', false)
end

local function apply_paste_plan(instance, win, cursor_row, cursor_col, input, plan)
  if input and plan.append_newline then
    input_model.fill_input(instance, input.name, input.value .. '\n', true)
    vim.api.nvim_win_set_cursor(win, { cursor_row, cursor_col })
  end

  if input and plan.cleanup_trailing_newline then
    vim.schedule(function()
      local updated = input_model.get_input_at_row(instance, cursor_row - 1)
      if updated and updated.value:sub(-1) == '\n' then
        vim.api.nvim_buf_set_lines(instance.state.buf, updated.end_row, updated.end_row + 1, true, {})
      end
    end)
  end

  feed_key(plan.key)
end

--- Check if backward deletion (BS, C-h, C-w, C-u) should be blocked at current position
--- @param instance table The Instance object holding UI state
--- @return boolean True if at the start boundary of an input field
function M.should_block_backward_delete(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row0, col = cursor[1] - 1, cursor[2]
  if col > 0 then
    return false
  end
  local input = input_model.get_input_at_row(instance, row0)
  return input ~= nil and input.start_row == row0
end

--- Check if forward deletion (Del) should be blocked at current position
--- @param instance table The Instance object holding UI state
--- @return boolean True if at the end boundary of an input field
function M.should_block_forward_delete(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row0, col = cursor[1] - 1, cursor[2]
  local line = vim.api.nvim_buf_get_lines(instance.state.buf, row0, row0 + 1, false)[1] or ''
  if col < #line then
    return false
  end
  local input = input_model.get_input_at_row(instance, row0)
  if not input then
    return false
  end
  return input.end_row == row0
end

--- Paste register contents after the current position, respecting input boundaries
--- @param instance table The Instance object holding UI state
--- @param is_visual boolean Whether triggered from visual mode
--- @return nil
function M.paste_below(instance, is_visual)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local cursor_row, cursor_col = cursor[1], cursor[2]
  local input = input_model.get_input_at_row(instance, cursor_row - 1)
  if get_search_scene().is_on_row(instance) then
    return
  end

  apply_paste_plan(instance, win, cursor_row, cursor_col, input, paste_plan.below(input, cursor_row - 1, is_visual))
end

--- Paste register contents before the current position, respecting input boundaries
--- @param instance table The Instance object holding UI state
--- @param is_visual boolean Whether triggered from visual mode
--- @return nil
function M.paste_above(instance, is_visual)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local cursor_row, cursor_col = cursor[1], cursor[2]
  local input = input_model.get_input_at_row(instance, cursor_row - 1)
  if get_search_scene().is_on_row(instance) then
    return
  end

  apply_paste_plan(instance, win, cursor_row, cursor_col, input, paste_plan.above(input, cursor_row - 1, is_visual))
end

--- Open a new line below the current position, respecting input boundaries
--- @param instance table The Instance object holding UI state
--- @return nil
function M.open_below(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return
  end

  local cursor_row = vim.api.nvim_win_get_cursor(win)[1]
  local input = input_model.get_input_at_row(instance, cursor_row - 1)
  if get_search_scene().is_on_row(instance) then
    return
  end
  if not input then
    feed_key('o')
    return
  end

  feed_key('A<CR>')
end

--- Move cursor to the start of a named input field
--- @param instance table The Instance object holding UI state
--- @param name string Input field name to jump to
--- @return nil
function M.goto_input(instance, name)
  local start_row = select(1, input_model.get_input_pos(instance, name))
  if not start_row then
    return
  end
  navigation.jump_to_row(instance, start_row + 1, false)
end

--- Move cursor to the first available input field
--- @param instance table The Instance object holding UI state
--- @return nil
function M.goto_first_input(instance)
  local name = input_sequence.first_name(instance.state.geometry.inputs, function(field)
    return not instance.state.detail_index or field.kind == 'detail'
  end)
  if name then
    M.goto_input(instance, name)
  end
end

--- Move cursor to the next input field, wrapping to first after last
--- @param instance table The Instance object holding UI state
--- @return nil
function M.goto_next_input(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return
  end

  local inputs = instance.state.geometry.inputs or {}
  local current = input_model.get_input_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
  local next_name = input_sequence.next_name(inputs, current and current.name or nil)
  if next_name then
    M.goto_input(instance, next_name)
  end
end

--- Move cursor to the previous input field, wrapping to last after first
--- @param instance table The Instance object holding UI state
--- @return nil
function M.goto_prev_input(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return
  end

  local inputs = instance.state.geometry.inputs or {}
  local current = input_model.get_input_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
  local prev_name = input_sequence.prev_name(inputs, current and current.name or nil)
  if prev_name then
    M.goto_input(instance, prev_name)
  end
end

return M
