local input_model = require('hlcraft.ui.input.model')
local navigation = require('hlcraft.ui.navigation')

local M = {}

local function get_workspace()
  return require('hlcraft.ui.workspace')
end

local function get_results_state()
  return require('hlcraft.ui.state.results')
end

--- Check if backward deletion (BS, C-h, C-w, C-u) should be blocked at current position
--- @param instance table The Instance object holding UI state
--- @return boolean True if at the start boundary of an input field
function M.should_block_backward_delete(instance)
  local workspace = get_workspace()
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
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
  local workspace = get_workspace()
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
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
  local workspace = get_workspace()
  local results_state = get_results_state()
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local cursor_row, cursor_col = cursor[1], cursor[2]
  local input = input_model.get_input_at_row(instance, cursor_row - 1)
  if results_state.is_on_row(instance) then
    return
  end
  if not input then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('p', true, false, true), 'n', false)
    return
  end

  local paste_cmd = 'p'
  if not is_visual then
    if input.end_row > input.start_row and cursor_row - 1 < input.end_row then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('p', true, false, true), 'n', false)
      return
    end
    if input.value == '' then
      paste_cmd = 'P'
    end
  end

  if paste_cmd == 'p' then
    input_model.fill_input(instance, input.name, input.value .. '\n', true)
    vim.api.nvim_win_set_cursor(win, { cursor_row, cursor_col })
  end

  vim.schedule(function()
    local updated = input_model.get_input_at_row(instance, cursor_row - 1)
    if updated and updated.value:sub(-1) == '\n' then
      vim.api.nvim_buf_set_lines(instance.state.buf, updated.end_row, updated.end_row + 1, true, {})
    end
  end)

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(paste_cmd, true, false, true), 'n', false)
end

--- Paste register contents before the current position, respecting input boundaries
--- @param instance table The Instance object holding UI state
--- @param is_visual boolean Whether triggered from visual mode
--- @return nil
function M.paste_above(instance, is_visual)
  local workspace = get_workspace()
  local results_state = get_results_state()
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local cursor_row, cursor_col = cursor[1], cursor[2]
  local input = input_model.get_input_at_row(instance, cursor_row - 1)
  if results_state.is_on_row(instance) then
    return
  end
  if not input then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('P', true, false, true), 'n', false)
    return
  end

  local delete_newline = false
  if not is_visual then
    if input.end_row > input.start_row and cursor_row - 1 < input.end_row then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('P', true, false, true), 'n', false)
      return
    end
    if input.value == '' then
      delete_newline = true
    end
  end

  if is_visual then
    input_model.fill_input(instance, input.name, input.value .. '\n', true)
    vim.api.nvim_win_set_cursor(win, { cursor_row, cursor_col })
    delete_newline = true
  end

  vim.schedule(function()
    local updated = input_model.get_input_at_row(instance, cursor_row - 1)
    if delete_newline and updated and updated.value:sub(-1) == '\n' then
      vim.api.nvim_buf_set_lines(instance.state.buf, updated.end_row, updated.end_row + 1, true, {})
    end
  end)

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('P', true, false, true), 'n', false)
end

--- Open a new line below the current position, respecting input boundaries
--- @param instance table The Instance object holding UI state
--- @return nil
function M.open_below(instance)
  local workspace = get_workspace()
  local results_state = get_results_state()
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
    return
  end

  local cursor_row = vim.api.nvim_win_get_cursor(win)[1]
  local input = input_model.get_input_at_row(instance, cursor_row - 1)
  if results_state.is_on_row(instance) then
    return
  end
  if not input then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('o', true, false, true), 'n', false)
    return
  end

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('A<CR>', true, false, true), 'n', false)
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
  for _, field in ipairs(instance.state.geometry.inputs or {}) do
    if not instance.state.detail_index or field.kind == 'detail' then
      M.goto_input(instance, field.key or field.name)
      return
    end
  end
end

--- Move cursor to the next input field, wrapping to first after last
--- @param instance table The Instance object holding UI state
--- @return nil
function M.goto_next_input(instance)
  local workspace = get_workspace()
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
    return
  end

  local inputs = instance.state.geometry.inputs or {}
  if #inputs == 0 then
    return
  end

  local current = input_model.get_input_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
  local next_name = inputs[1].key or inputs[1].name
  if current then
    for index, input in ipairs(inputs) do
      local input_name = input.key or input.name
      if input_name == current.name then
        local next_input = inputs[index + 1] or inputs[1]
        next_name = next_input.key or next_input.name
        break
      end
    end
  end

  M.goto_input(instance, next_name)
end

--- Move cursor to the previous input field, wrapping to last after first
--- @param instance table The Instance object holding UI state
--- @return nil
function M.goto_prev_input(instance)
  local workspace = get_workspace()
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
    return
  end

  local inputs = instance.state.geometry.inputs or {}
  if #inputs == 0 then
    return
  end

  local current = input_model.get_input_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
  local prev_name = inputs[#inputs].key or inputs[#inputs].name
  if current then
    for index, input in ipairs(inputs) do
      local input_name = input.key or input.name
      if input_name == current.name then
        local prev_input = inputs[index - 1] or inputs[#inputs]
        prev_name = prev_input.key or prev_input.name
        break
      end
    end
  end

  M.goto_input(instance, prev_name)
end

return M
