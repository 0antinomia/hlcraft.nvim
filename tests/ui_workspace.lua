local h = require('tests.helpers')
local scope = 'hlcraft ui workspace'

local window_options = require('hlcraft.ui.window_options')
local help = require('hlcraft.ui.help')
local Instance = require('hlcraft.ui.instance')

local win = vim.api.nvim_get_current_win()
local original = window_options.snapshot(win)

vim.wo[win].number = true
vim.wo[win].relativenumber = true
vim.wo[win].signcolumn = 'yes'
vim.wo[win].foldcolumn = '1'

local snapshot = window_options.snapshot(win)
window_options.apply(win, 0)
h.assert_equal(vim.wo[win].number, false, 'workspace number option was not applied', scope)
h.assert_equal(vim.wo[win].relativenumber, false, 'workspace relativenumber option was not applied', scope)
h.assert_equal(vim.wo[win].signcolumn, 'no', 'workspace signcolumn option was not applied', scope)
h.assert_equal(vim.wo[win].foldcolumn, '0', 'workspace foldcolumn option was not applied', scope)
h.assert_true(
  window_options.matches_workspace(window_options.read(win)),
  'workspace option matcher rejected applied values',
  scope
)

local restored = window_options.restore(snapshot)
h.assert_true(restored, 'window option restore returned false', scope)
h.assert_equal(vim.wo[win].number, true, 'number option was not restored', scope)
h.assert_equal(vim.wo[win].relativenumber, true, 'relativenumber option was not restored', scope)
h.assert_equal(vim.wo[win].signcolumn, 'yes', 'signcolumn option was not restored', scope)
h.assert_equal(vim.wo[win].foldcolumn, '1', 'foldcolumn option was not restored', scope)

local instance = Instance.new('ui-workspace-test')
help.toggle(instance)
h.assert_true(help.is_open(instance), 'help window did not open', scope)
h.assert_true(
  instance.state.help_buf ~= nil and vim.api.nvim_buf_is_valid(instance.state.help_buf),
  'help buffer invalid',
  scope
)
help.toggle(instance)
h.assert_true(not help.is_open(instance), 'help window did not close', scope)
help.delete_buffer(instance)
h.assert_true(instance.state.help_buf == nil, 'help buffer state was not cleared', scope)

window_options.restore(original)
print('hlcraft ui workspace: OK')
