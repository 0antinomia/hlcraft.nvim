local h = require('tests.helpers')
local scope = 'hlcraft ui handles'

local handles = require('hlcraft.ui.handles')
local ui = require('hlcraft.ui')

h.assert_true(not handles.is_valid_buf(nil), 'nil buffer was valid', scope)
h.assert_true(not handles.is_valid_win(nil), 'nil window was valid', scope)

local buf = vim.api.nvim_create_buf(false, true)
h.assert_true(handles.is_valid_buf(buf), 'created buffer was not valid', scope)
vim.api.nvim_buf_delete(buf, { force = true })
h.assert_true(not handles.is_valid_buf(buf), 'deleted buffer stayed valid', scope)

h.assert_true(handles.is_valid_win(vim.api.nvim_get_current_win()), 'current window was not valid', scope)
local invalid_instance_name_ok = pcall(ui.get_instance, false)
h.assert_true(not invalid_instance_name_ok, 'UI accepted non-string instance name', scope)
local invalid_open_opts_ok = pcall(ui.open, false)
h.assert_true(not invalid_open_opts_ok, 'UI open accepted non-table options', scope)

print('hlcraft ui handles: OK')
