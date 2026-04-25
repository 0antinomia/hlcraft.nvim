local h = require('tests.helpers')

local function assert_equal(actual, expected, message)
  return h.assert_equal(actual, expected, message, 'hlcraft origin-window switch')
end

vim.cmd('runtime plugin/hlcraft.lua')

local hlcraft = require('hlcraft')
local ui = require('hlcraft.ui')

local persist_dir = vim.fn.stdpath('cache') .. '/hlcraft-origin-window-switch'
vim.fn.delete(persist_dir, 'rf')

local origin_win = vim.api.nvim_get_current_win()
local original_window_options = {
  number = true,
  relativenumber = true,
  signcolumn = 'yes',
  foldcolumn = '1',
}
local workspace_window_options = {
  number = false,
  relativenumber = false,
  signcolumn = 'no',
  foldcolumn = '0',
}

for option, value in pairs(original_window_options) do
  vim.wo[origin_win][option] = value
end

hlcraft.setup({ persist_dir = persist_dir, debounce_ms = 0 })
hlcraft.open()

local instance = ui.get_instance()
assert_equal(vim.api.nvim_get_current_buf(), instance.state.buf, 'workspace buffer did not open in the current window')

for option, value in pairs(workspace_window_options) do
  assert_equal(vim.wo[origin_win][option], value, ('workspace window option %s was not applied'):format(option))
end

vim.cmd('edit hlcraft-origin-window-switch.txt')

for option, value in pairs(original_window_options) do
  assert_equal(
    vim.wo[origin_win][option],
    value,
    ('origin window option %s leaked after switching buffers'):format(option)
  )
end

vim.cmd('buffer ' .. instance.state.buf)
for option, value in pairs(workspace_window_options) do
  assert_equal(
    vim.wo[origin_win][option],
    value,
    ('workspace window option %s was not reapplied after returning'):format(option)
  )
end

instance:quit_or_back()
for option, value in pairs(original_window_options) do
  assert_equal(
    vim.wo[origin_win][option],
    value,
    ('origin window option %s was not restored after close'):format(option)
  )
end

vim.fn.delete(persist_dir, 'rf')
print('hlcraft origin-window switch: OK')
