local window = require('hlcraft.ui.workspace.window')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')

local M = {}

M.is_valid_buf = window.is_valid_buf
M.is_valid_win = window.is_valid_win
M.get_win = window.get_win
M.is_open = window.is_open
M.capture_workspace_window = window.capture_workspace_window
M.release_workspace_window = window.release_workspace_window

M.toggle_help = lifecycle.toggle_help
M.open = lifecycle.open
M.hide = lifecycle.hide
M.close = lifecycle.close
M.cleanup = lifecycle.cleanup

return M
