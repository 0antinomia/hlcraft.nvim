local function fail(message)
  error('hlcraft smoke: ' .. message, 0)
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    fail(('%s (expected %s, got %s)'):format(message, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function find_result_line(instance, index)
  for line, result_index in pairs(instance.state.geometry.result_lines or {}) do
    if result_index == index then
      return line
    end
  end
  return nil
end

local persist_dir = vim.fn.stdpath('cache') .. '/hlcraft-smoke'
vim.fn.delete(persist_dir, 'rf')

vim.cmd('runtime plugin/hlcraft.lua')

assert_true(vim.fn.exists(':Hlcraft') == 2, ':Hlcraft command is not registered')

local hlcraft = require('hlcraft')
local ui = require('hlcraft.ui')
local input_model = require('hlcraft.ui.input.model')
local detail_form_state = require('hlcraft.ui.state.detail_form')
local results_state = require('hlcraft.ui.state.results')
local overrides = require('hlcraft.overrides')
local storage = require('hlcraft.storage')

local origin_win = vim.api.nvim_get_current_win()
local origin_buf = vim.api.nvim_get_current_buf()
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
local secondary_window_options = {
  number = true,
  relativenumber = false,
  signcolumn = 'yes:1',
  foldcolumn = '2',
}

for option, value in pairs(original_window_options) do
  vim.wo[origin_win][option] = value
end

hlcraft.setup({ persist_dir = persist_dir, debounce_ms = 0 })
hlcraft.open()

local instance = ui.get_instance()
assert_true(instance.state.buf and vim.api.nvim_buf_is_valid(instance.state.buf), 'workspace buffer is invalid')

local win = vim.fn.bufwinid(instance.state.buf)
assert_true(win ~= -1 and vim.api.nvim_win_is_valid(win), 'workspace window is not open')
assert_equal(win, origin_win, 'workspace did not reuse the origin window')

for option, value in pairs(workspace_window_options) do
  assert_equal(vim.wo[win][option], value, ('workspace window option %s was not applied'):format(option))
end

vim.cmd('edit smoke-origin-switch.txt')
for option, value in pairs(original_window_options) do
  assert_equal(vim.wo[origin_win][option], value, ('origin file window option %s leaked from workspace'):format(option))
end
vim.cmd('buffer ' .. instance.state.buf)
for option, value in pairs(workspace_window_options) do
  assert_equal(vim.wo[origin_win][option], value, ('workspace window option %s was not reapplied after returning'):format(option))
end

vim.cmd('vsplit')
local secondary_win = vim.api.nvim_get_current_win()
assert_true(secondary_win ~= origin_win, 'failed to open secondary window')
for option, value in pairs(secondary_window_options) do
  vim.wo[secondary_win][option] = value
end
vim.api.nvim_win_set_buf(secondary_win, instance.state.buf)
require('hlcraft.ui.workspace').capture_workspace_window(instance, secondary_win)
for option, value in pairs(workspace_window_options) do
  assert_equal(vim.wo[secondary_win][option], value, ('secondary workspace window option %s was not applied'):format(option))
end
vim.cmd('edit smoke-secondary.txt')
require('hlcraft.ui.workspace').release_workspace_window(instance, secondary_win)
for option, value in pairs(secondary_window_options) do
  assert_equal(vim.wo[secondary_win][option], value, ('secondary file window option %s leaked from workspace'):format(option))
end
vim.api.nvim_set_current_win(origin_win)

input_model.fill_input(instance, 'name', 'normal', true)
input_model.fill_input(instance, 'color', '', true)
input_model.sync_queries_from_buffer(instance)
instance:rerender()

assert_equal(instance.state.name_query, 'normal', 'name query did not sync from buffer')
assert_true(#instance.state.results > 0, 'search produced no results for query "normal"')

local target_line = find_result_line(instance, 1)
assert_true(target_line ~= nil, 'failed to find first result line')
vim.api.nvim_win_set_cursor(win, { target_line, 0 })

results_state.open_detail(instance)
assert_equal(instance.state.detail_index, 1, 'detail view did not open for first result')
assert_true(instance.state.geometry.detail_fields.group ~= nil, 'detail fields were not rendered')

local result_name = instance.state.results[instance.state.detail_index].name
local runtime_before = overrides.get(result_name)
assert_true(type(runtime_before) == 'table', 'failed to read runtime override state')

input_model.fill_input(instance, 'fg', '#112233', true)
input_model.fill_input(instance, 'group', 'smoke', true)
detail_form_state.sync_from_buffer(instance)
detail_form_state.apply(instance)

local runtime_after = overrides.get(result_name)
assert_equal(runtime_after.fg, '#112233', 'detail apply did not update runtime fg override')
assert_true(overrides.has_runtime(result_name), 'runtime override flag was not set')
assert_equal(overrides.get_runtime_group(result_name), 'smoke', 'runtime group was not updated')

local file_path = overrides.file_path(result_name)
assert_true(vim.uv.fs_stat(file_path) ~= nil, 'persisted TOML file was not created')

local loaded = storage.load(persist_dir)
assert_true(loaded.entries[result_name] ~= nil, 'persisted entry was not saved')
assert_equal(loaded.entries[result_name].fg, '#112233', 'persisted fg override is incorrect')
assert_equal(loaded.groups[result_name], 'smoke', 'persisted group name is incorrect')

overrides.bootstrap(true)
assert_equal(overrides.get_persisted(result_name).fg, '#112233', 'persisted override did not reload after bootstrap')
assert_equal(overrides.get_persisted_group(result_name), 'smoke', 'persisted group did not reload after bootstrap')

instance:quit_or_back()
assert_true(instance.state.detail_index == nil, 'detail view did not close')
assert_true(vim.api.nvim_buf_is_valid(instance.state.buf), 'workspace buffer disappeared after closing detail view')

instance:quit_or_back()
assert_true(
  instance.state.buf == nil or not vim.api.nvim_buf_is_valid(instance.state.buf),
  'workspace buffer was not deleted on quit'
)
assert_true(vim.api.nvim_win_is_valid(origin_win), 'origin window is invalid after quit')
assert_equal(vim.api.nvim_win_get_buf(origin_win), origin_buf, 'origin buffer was not restored after quit')

for option, value in pairs(original_window_options) do
  assert_equal(vim.wo[origin_win][option], value, ('origin window option %s was not restored'):format(option))
end

vim.fn.delete(persist_dir, 'rf')

print('hlcraft smoke: OK')
