local search_scene = require('hlcraft.ui.scene.search')
local detail_scene = require('hlcraft.ui.scene.detail')

local M = {}

M.empty_message = search_scene.empty_message
M.update_results = search_scene.update_results
M.rows = search_scene.rows
M.current_entry = search_scene.current_entry
M.is_on_row = search_scene.is_on_row
M.goto_offset = search_scene.goto_offset
M.goto_first = search_scene.goto_first
M.open_detail = search_scene.open_detail

M.current_detail_result = detail_scene.current_result
M.refresh = detail_scene.refresh
M.close_unsaved_prompt = detail_scene.close_unsaved_prompt
M.force_close_detail = detail_scene.force_close
M.close_detail = detail_scene.close
M.open_unsaved_prompt = detail_scene.open_unsaved_prompt

return M
