local input_model = require('hlcraft.ui.input.model')
local paste_plan = require('hlcraft.ui.input.paste_plan')
local input_sequence = require('hlcraft.ui.input.sequence')
local buffer_lines = require('hlcraft.ui.buffer_lines')
local navigation = require('hlcraft.ui.navigation')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('input actions require an instance', 3)
  end
  return instance.state
end

local function geometry_inputs(state)
  if type(state.geometry) ~= 'table' then
    error('input actions geometry must be a table', 3)
  end
  local inputs = state.geometry.inputs
  if type(inputs) ~= 'table' then
    error('input actions geometry inputs must be a table', 3)
  end
  if not tables.is_sequence(inputs) then
    error('input actions geometry inputs must be a sequence', 3)
  end
  return inputs
end

local function assert_visual_flag(is_visual)
  if type(is_visual) ~= 'boolean' then
    error('input visual flag must be boolean', 3)
  end
  return is_visual
end

local function detail_active(state)
  local index = state.detail_index
  if index == nil then
    return false
  end
  if type(index) ~= 'number' then
    error('input action detail index must be a number or nil', 3)
  end
  if not numbers.is_finite(index) or math.floor(index) ~= index or index < 1 then
    error('input action detail index must be a positive finite integer or nil', 3)
  end
  return true
end

local function get_search_scene()
  return require('hlcraft.ui.scene.search')
end

local function feed_key(key)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'n', false)
end

local function cursor_context(instance)
  local state = instance_state(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local row1, col = cursor[1], cursor[2]
  return {
    win = win,
    state = state,
    row1 = row1,
    row0 = row1 - 1,
    col = col,
    input = input_model.get_input_at_row(instance, row1 - 1),
  }
end

local function apply_paste_plan(instance, win, cursor_row, cursor_col, input, plan)
  if input and plan.append_newline then
    input_model.fill_input(instance, input.name, input.value .. '\n', true)
    vim.api.nvim_win_set_cursor(win, { cursor_row, cursor_col })
  end

  if input and plan.cleanup_trailing_newline then
    vim.schedule(function()
      local updated = input_model.get_input_at_row(instance, cursor_row - 1)
      if updated then
        input_model.remove_trailing_empty_line(instance, updated.name)
      end
    end)
  end

  feed_key(plan.key)
end

local function paste_with_plan(instance, is_visual, planner)
  is_visual = assert_visual_flag(is_visual)
  local context = cursor_context(instance)
  if not context or get_search_scene().is_on_row(instance) then
    return
  end

  local plan = planner(context.input, context.row0, is_visual)
  apply_paste_plan(instance, context.win, context.row1, context.col, context.input, plan)
end

local function goto_relative_input(instance, resolve_name)
  local context = cursor_context(instance)
  if not context then
    return
  end

  local name = resolve_name(geometry_inputs(context.state), context.input and context.input.name or nil)
  if name then
    M.goto_input(instance, name)
  end
end

--- Check if backward deletion (BS, C-h, C-w, C-u) should be blocked at current position
--- @param instance table The Instance object holding UI state
--- @return boolean True if at the start boundary of an input field
function M.should_block_backward_delete(instance)
  local context = cursor_context(instance)
  if not context then
    return false
  end
  if context.col > 0 then
    return false
  end
  return context.input ~= nil and context.input.start_row == context.row0
end

--- Check if forward deletion (Del) should be blocked at current position
--- @param instance table The Instance object holding UI state
--- @return boolean True if at the end boundary of an input field
function M.should_block_forward_delete(instance)
  local context = cursor_context(instance)
  if not context then
    return false
  end
  local line = buffer_lines.line(context.state.buf, context.row0, 'cursor input action')
  if context.col < #line then
    return false
  end
  if not context.input then
    return false
  end
  return context.input.end_row == context.row0
end

--- Paste register contents after the current position, respecting input boundaries
--- @param instance table The Instance object holding UI state
--- @param is_visual boolean Whether triggered from visual mode
--- @return nil
function M.paste_below(instance, is_visual)
  paste_with_plan(instance, is_visual, paste_plan.below)
end

--- Paste register contents before the current position, respecting input boundaries
--- @param instance table The Instance object holding UI state
--- @param is_visual boolean Whether triggered from visual mode
--- @return nil
function M.paste_above(instance, is_visual)
  paste_with_plan(instance, is_visual, paste_plan.above)
end

--- Open a new line below the current position, respecting input boundaries
--- @param instance table The Instance object holding UI state
--- @return nil
function M.open_below(instance)
  local context = cursor_context(instance)
  if not context then
    return
  end

  if get_search_scene().is_on_row(instance) then
    return
  end
  if not context.input then
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
  local state = instance_state(instance)
  local is_detail = detail_active(state)
  local name = input_sequence.first_name(geometry_inputs(state), function(field)
    return not is_detail or field.kind == 'detail'
  end)
  if name then
    M.goto_input(instance, name)
  end
end

--- Move cursor to the next input field, wrapping to first after last
--- @param instance table The Instance object holding UI state
--- @return nil
function M.goto_next_input(instance)
  goto_relative_input(instance, input_sequence.next_name)
end

--- Move cursor to the previous input field, wrapping to last after first
--- @param instance table The Instance object holding UI state
--- @return nil
function M.goto_prev_input(instance)
  goto_relative_input(instance, input_sequence.prev_name)
end

return M
