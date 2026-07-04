local model = require('hlcraft.ui.input.model')
local actions = require('hlcraft.ui.input.actions')

local M = {}

M.current_area = model.current_area
M.normalize_single_line = model.normalize_single_line
M.set_extmarks = model.set_input_extmarks
M.get_pos = model.get_input_pos
M.get_lines = model.get_input_lines
M.get_value = model.get_input_value
M.fill = model.fill_input
M.get_at_row = model.get_input_at_row
M.field_line_text = model.field_line_text
M.sync_queries = model.sync_queries_from_buffer

M.should_block_backward_delete = actions.should_block_backward_delete
M.should_block_forward_delete = actions.should_block_forward_delete
M.paste_below = actions.paste_below
M.paste_above = actions.paste_above
M.open_below = actions.open_below
M.goto_input = actions.goto_input
M.goto_first = actions.goto_first_input
M.goto_next = actions.goto_next_input
M.goto_prev = actions.goto_prev_input

return M
