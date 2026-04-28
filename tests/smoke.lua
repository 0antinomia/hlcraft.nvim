local h = require('tests.helpers')

local function assert_true(condition, message)
  return h.assert_true(condition, message, 'hlcraft smoke')
end

local function assert_equal(actual, expected, message)
  return h.assert_equal(actual, expected, message, 'hlcraft smoke')
end

local function assert_file_missing(path, message)
  return h.assert_file_missing(path, message, 'hlcraft smoke')
end

local find_result_line = h.find_result_line
local press_normal = h.press_normal
local list_contains = h.list_contains

local persist_dir = vim.fn.stdpath('cache') .. '/hlcraft-smoke'
vim.fn.delete(persist_dir, 'rf')

vim.cmd('runtime plugin/hlcraft.lua')

assert_true(vim.fn.exists(':Hlcraft') == 2, ':Hlcraft command is not registered')

local hlcraft = require('hlcraft')
local ui = require('hlcraft.ui')
local input_model = require('hlcraft.ui.input.model')
local field_editor = require('hlcraft.ui.state.field_editor')
local detail_values = require('hlcraft.ui.state.detail_values')
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

assert_equal(overrides.get_runtime_group('Normal'), nil, 'missing runtime group fell back to default')
assert_equal(overrides.get_persisted_group('Normal'), nil, 'missing persisted group fell back to default')
assert_equal(#overrides.known_groups(), 0, 'known groups included an implicit default group')

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
  assert_equal(
    vim.wo[origin_win][option],
    value,
    ('workspace window option %s was not reapplied after returning'):format(option)
  )
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
  assert_equal(
    vim.wo[secondary_win][option],
    value,
    ('secondary workspace window option %s was not applied'):format(option)
  )
end
vim.cmd('edit smoke-secondary.txt')
require('hlcraft.ui.workspace').release_workspace_window(instance, secondary_win)
for option, value in pairs(secondary_window_options) do
  assert_equal(
    vim.wo[secondary_win][option],
    value,
    ('secondary file window option %s leaked from workspace'):format(option)
  )
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
assert_true(instance.state.geometry.detail_menu ~= nil, 'detail menu geometry was not initialized')
assert_true(instance.state.geometry.detail_menu.group ~= nil, 'group row was not rendered as a menu item')
assert_true(instance.state.geometry.detail_menu.fg ~= nil, 'fg row was not rendered as a menu item')
assert_true(instance.state.field_editor.field == nil, 'field editor should not be open initially')
assert_equal(
  vim.api.nvim_win_get_cursor(win)[1],
  instance.state.geometry.detail_menu.group.line,
  'cursor did not move to first detail menu row'
)

local group_line = instance.state.geometry.detail_menu.group.line
local fg_line = instance.state.geometry.detail_menu.fg.line
local lines = vim.api.nvim_buf_get_lines(instance.state.buf, group_line - 1, fg_line, false)
assert_true(lines[1]:find('Group') ~= nil, 'group menu row does not show label')
assert_true(lines[1]:find('unset') ~= nil, 'unset group row does not show unset state')
assert_true(lines[1]:find('default') == nil, 'unset group row displayed an implicit default group')
assert_true(lines[#lines]:find('FG') ~= nil, 'fg menu row does not show label')

local result_name = instance.state.results[instance.state.detail_index].name
local runtime_before = overrides.get(result_name)
assert_true(type(runtime_before) == 'table', 'failed to read runtime override state')

field_editor.open(instance, 'group')
assert_true(instance.state.geometry.editor_rows.new_group ~= nil, 'empty group editor did not offer new group')
assert_true(
  instance.state.geometry.editor_rows['group:default'] == nil,
  'empty group editor offered implicit default group'
)
field_editor.close(instance)

vim.api.nvim_win_set_cursor(win, { instance.state.geometry.detail_menu.bold.line, 0 })
field_editor.activate(instance)
assert_equal(overrides.get(result_name).bold, true, 'bold did not toggle to true')
field_editor.activate(instance)
assert_equal(overrides.get(result_name).bold, false, 'bold did not toggle to false')
field_editor.activate(instance)
assert_true(overrides.get(result_name).bold == nil, 'bold did not toggle back to unset')

vim.api.nvim_win_set_cursor(win, { instance.state.geometry.detail_menu.fg.line, 0 })
field_editor.activate(instance)
assert_equal(instance.state.field_editor.field, 'fg', 'fg editor did not open')
local editor_lines = table.concat(vim.api.nvim_buf_get_lines(instance.state.buf, 0, -1, false), '\n')
assert_true(editor_lines:find('Color editor: FG') ~= nil, 'color editor title missing')
assert_true(editor_lines:find('r/R') ~= nil, 'color editor shortcuts missing')
local editor_file_path = overrides.file_path(result_name)
field_editor.set_color(instance, '#112233')
field_editor.adjust_color(instance, 'r', 5)
assert_equal(overrides.get(result_name).fg, '#162233', 'red channel did not increase by 5')
local missing_group_save_ok, missing_group_save_err = detail_values.save(instance, result_name)
assert_true(not missing_group_save_ok, 'saving override without group unexpectedly succeeded')
assert_true(
  tostring(missing_group_save_err or ''):find('group') ~= nil,
  'saving override without group did not report missing group'
)
assert_file_missing(editor_file_path, 'saving override without group created TOML')
press_normal('r')
assert_equal(overrides.get(result_name).fg, '#112233', 'r key did not decrease red channel in color editor')
press_normal('G')
assert_equal(overrides.get(result_name).fg, '#112733', 'G key did not increase green channel in color editor')
press_normal('g')
assert_equal(overrides.get(result_name).fg, '#112233', 'g key did not decrease green channel in color editor')

press_normal('d')
assert_equal(overrides.get(result_name).dynamic.fg.mode, 'rgb', 'd key did not enable dynamic fg')
assert_equal(overrides.get(result_name).dynamic.fg.speed, 2000, 'dynamic fg default speed is wrong')
local dynamic_editor_text = table.concat(vim.api.nvim_buf_get_lines(instance.state.buf, 0, -1, false), '\n')
assert_true(dynamic_editor_text:find('Mode: dynamic', 1, true) ~= nil, 'dynamic editor did not render after d key')

press_normal('m')
assert_equal(overrides.get(result_name).dynamic.fg.mode, 'breath', 'm key did not cycle dynamic mode')
press_normal('+')
assert_equal(overrides.get(result_name).dynamic.fg.speed, 2250, '+ key did not increase dynamic speed')
press_normal('-')
assert_equal(overrides.get(result_name).dynamic.fg.speed, 2000, '- key did not decrease dynamic speed')

press_normal('r')
assert_equal(overrides.get(result_name).fg, '#112233', 'r key mutated static color in dynamic mode')
press_normal('d')
assert_true(overrides.get(result_name).dynamic == nil, 'd key did not disable dynamic fg')

field_editor.open(instance, 'blend')
field_editor.set_blend(instance, 10)
press_normal('+')
assert_equal(overrides.get(result_name).blend, 11, '+ key did not adjust blend in blend editor')
press_normal('u')
assert_true(overrides.get(result_name).blend == nil, 'u key did not unset blend in blend editor')
field_editor.set_blend(instance, 10)
press_normal('G')
assert_equal(overrides.get(result_name).fg, '#112233', 'G key mutated color in blend editor')
press_normal('g')
assert_equal(overrides.get(result_name).fg, '#112233', 'g key mutated color in blend editor')

field_editor.open(instance, 'group')
local group_blend_before = overrides.get(result_name).blend
local group_fg_before = overrides.get(result_name).fg
press_normal('+')
press_normal('G')
press_normal('g')
assert_equal(overrides.get(result_name).blend, group_blend_before, 'blend key mutated blend in group editor')
assert_equal(overrides.get(result_name).fg, group_fg_before, 'color key mutated color in group editor')

field_editor.open(instance, 'fg')
assert_file_missing(editor_file_path, 'color adjustment saved before explicit save')
field_editor.set_group(instance, 'smoke-new')
assert_equal(overrides.get_runtime_group(result_name), 'smoke-new', 'new group was not applied at runtime')
assert_file_missing(overrides.file_path(result_name), 'group runtime edit saved before explicit save')
local group_file_path = overrides.file_path(result_name)
local editor_save_ok, editor_save_err = detail_values.save(instance, result_name)
assert_true(editor_save_ok, editor_save_err or 'save failed')
assert_equal(instance.state.field_editor.field, 'fg', 'field editor did not stay open after explicit save')
assert_true(vim.uv.fs_stat(group_file_path) ~= nil, 'explicit save did not create TOML')
local group_loaded = storage.load(persist_dir)
assert_equal(group_loaded.groups[result_name], 'smoke-new', 'saved group name is incorrect')
field_editor.set_group(instance, 'smoke-temp')
assert_equal(overrides.get_runtime_group(result_name), 'smoke-temp', 'runtime-only group edit was not applied')
field_editor.open(instance, 'group')
local smoke_new_row = instance.state.geometry.editor_rows['group:smoke-new']
assert_true(smoke_new_row ~= nil, 'saved group row was not rendered in group editor')
vim.api.nvim_win_set_cursor(win, { smoke_new_row.line, 0 })
field_editor.activate(instance)
assert_equal(overrides.get_runtime_group(result_name), 'smoke-new', 'group row activation did not select group')
field_editor.set_group(instance, 'smoke-temp')
assert_equal(
  overrides.get_runtime_group(result_name),
  'smoke-temp',
  'runtime-only group edit was not applied after activation'
)
local group_discard_ok, group_discard_err = detail_values.discard(instance, result_name)
assert_true(group_discard_ok, group_discard_err or 'discarding group failed')
assert_equal(overrides.get_runtime_group(result_name), 'smoke-new', 'discard did not restore persisted group')
local group_discard_loaded = storage.load(persist_dir)
assert_equal(group_discard_loaded.groups[result_name], 'smoke-new', 'discarded group runtime edit changed TOML')
overrides.clear(result_name)
local editor_clear_ok, editor_clear_err = detail_values.save(instance, result_name)
assert_true(editor_clear_ok, editor_clear_err or 'failed to reset editor save smoke state')
assert_file_missing(group_file_path, 'editor save smoke reset left TOML behind')

instance:quit_or_back()
assert_true(instance.state.detail_index == nil, 'detail view did not close after opening field editor')
assert_true(instance.state.field_editor.field == nil, 'field editor was not cleared when detail closed')
results_state.open_detail(instance)
assert_equal(instance.state.detail_index, 1, 'detail view did not reopen after closing field editor')
assert_true(instance.state.field_editor.field == nil, 'field editor stayed open after reopening detail')

instance.state.name_query = '__hlcraft_smoke_no_match__'
local missing_ok, missing_err = detail_values.apply_runtime(instance, result_name, { bold = true })
assert_true(missing_ok, missing_err or 'runtime apply for disappearing result failed')
assert_true(instance.state.detail_index == nil, 'detail stayed open after refreshed result disappeared')
assert_true(instance.state.field_editor.field == nil, 'field editor stayed open after refreshed result disappeared')
assert_true(
  results_state.current_detail_result(instance) == nil,
  'stale detail result remained after refreshed result disappeared'
)

instance.state.name_query = 'normal'
instance:rerender()
local restored_target_line = find_result_line(instance, 1)
assert_true(restored_target_line ~= nil, 'failed to restore result line after disappearing-result regression')
vim.api.nvim_win_set_cursor(win, { restored_target_line, 0 })
results_state.open_detail(instance)
assert_equal(instance.state.detail_index, 1, 'detail view did not reopen after disappearing-result regression')
local clear_bold_ok, clear_bold_err = detail_values.apply_runtime(instance, result_name, { bold = vim.NIL })
assert_true(clear_bold_ok, clear_bold_err or 'failed to clear disappearing-result bold override')
assert_true(overrides.get(result_name).bold == nil, 'disappearing-result bold override was not cleared')

local dirty_close_ok, dirty_close_err = detail_values.apply_runtime(instance, result_name, { fg = '#445566' })
assert_true(dirty_close_ok, dirty_close_err or 'runtime apply for dirty close prompt failed')
results_state.close_detail(instance)
assert_true(instance.state.detail_index ~= nil, 'dirty detail closed without confirmation')
assert_true(instance.state.unsaved_prompt.win ~= nil, 'unsaved prompt was not opened')
assert_equal(
  vim.api.nvim_get_current_win(),
  instance.state.unsaved_prompt.win,
  'unsaved prompt mappings are unreachable'
)
press_normal('d')
assert_true(instance.state.detail_index == nil, 'discard prompt mapping did not close detail')
assert_true(instance.state.unsaved_prompt.win == nil, 'discard prompt mapping did not close prompt')

local detail_target_line = find_result_line(instance, 1)
assert_true(detail_target_line ~= nil, 'failed to find first result line after prompt discard')
vim.api.nvim_win_set_cursor(win, { detail_target_line, 0 })
results_state.open_detail(instance)
assert_equal(instance.state.detail_index, 1, 'detail view did not reopen after prompt discard')

local runtime_file_path = overrides.file_path(result_name)
assert_file_missing(runtime_file_path, 'TOML file existed before explicit save')

local runtime_ok, runtime_err = detail_values.apply_runtime(instance, result_name, { fg = '#112233', group = 'smoke' })
assert_true(runtime_ok, runtime_err or 'runtime apply failed')
assert_equal(overrides.get(result_name).fg, '#112233', 'runtime fg was not updated immediately')
assert_equal(overrides.get_runtime_group(result_name), 'smoke', 'runtime group was not updated immediately')
assert_file_missing(runtime_file_path, 'runtime-only edit unexpectedly saved TOML')

local invalid_ok = detail_values.apply_runtime(instance, result_name, { fg = 'not-a-color' })
assert_true(not invalid_ok, 'invalid runtime patch unexpectedly succeeded')
assert_equal(overrides.get(result_name).fg, '#112233', 'failed runtime patch did not preserve previous fg')
assert_equal(overrides.get_runtime_group(result_name), 'smoke', 'failed runtime patch did not preserve previous group')
assert_file_missing(runtime_file_path, 'failed runtime patch unexpectedly saved TOML')

local original_storage_save = storage.save
local persisted_group_before_failed_save = overrides.get_persisted_group(result_name)
---@diagnostic disable-next-line: duplicate-set-field
storage.save = function()
  return false, 'smoke forced save failure'
end
local save_ok = detail_values.save(instance, result_name)
storage.save = original_storage_save
assert_true(not save_ok, 'forced save failure unexpectedly succeeded')
assert_equal(overrides.get_persisted(result_name).fg, nil, 'failed save updated persisted fg state')
assert_equal(
  overrides.get_persisted_group(result_name),
  persisted_group_before_failed_save,
  'failed save updated persisted group state'
)
assert_equal(overrides.get(result_name).fg, '#112233', 'failed save changed runtime fg')
assert_equal(overrides.get_runtime_group(result_name), 'smoke', 'failed save changed runtime group')
assert_file_missing(runtime_file_path, 'failed save unexpectedly created TOML')

local save_success_ok, save_success_err = detail_values.save(instance, result_name)
assert_true(save_success_ok, save_success_err or 'save failed')

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

local group_only_name = 'Comment'
overrides.clear(group_only_name)
local group_only_ok, group_only_err = detail_values.apply_runtime(nil, group_only_name, { group = 'smoke-group-only' })
assert_true(group_only_ok, group_only_err or 'group-only runtime apply failed')
assert_equal(
  overrides.get_runtime_group(group_only_name),
  'smoke-group-only',
  'group-only runtime group was not updated'
)
assert_equal(next(overrides.get(group_only_name)), nil, 'group-only runtime edit added override fields')
local group_only_save_ok, group_only_save_err = detail_values.save(nil, group_only_name)
assert_true(group_only_save_ok, group_only_save_err or 'group-only save failed')
local group_only_loaded = storage.load(persist_dir)
assert_equal(
  group_only_loaded.groups[group_only_name],
  'smoke-group-only',
  'group-only save did not persist group name'
)
assert_equal(next(group_only_loaded.entries[group_only_name]), nil, 'group-only save persisted override fields')
overrides.bootstrap(true)
assert_equal(
  overrides.get_persisted_group(group_only_name),
  'smoke-group-only',
  'group-only persisted group did not reload after bootstrap'
)

local explicit_default_name = 'Identifier'
overrides.clear(explicit_default_name)
local explicit_default_ok, explicit_default_err =
  detail_values.apply_runtime(nil, explicit_default_name, { group = 'default' })
assert_true(explicit_default_ok, explicit_default_err or 'explicit default group runtime apply failed')
local explicit_default_save_ok, explicit_default_save_err = detail_values.save(nil, explicit_default_name)
assert_true(explicit_default_save_ok, explicit_default_save_err or 'explicit default group save failed')
local explicit_default_loaded = storage.load(persist_dir)
assert_equal(
  explicit_default_loaded.groups[explicit_default_name],
  'default',
  'explicit default group was not treated as a normal persisted group'
)
assert_true(
  list_contains(overrides.known_groups(), 'default'),
  'explicit default group was not listed as a normal known group'
)

local clear_last_field_name = 'LineNr'
overrides.clear(clear_last_field_name)
local clear_last_group_ok, clear_last_group_err =
  detail_values.apply_runtime(nil, clear_last_field_name, { group = 'smoke-clear-last' })
assert_true(clear_last_group_ok, clear_last_group_err or 'clear-last group runtime apply failed')
local clear_last_fg_ok, clear_last_fg_err = detail_values.apply_runtime(nil, clear_last_field_name, { fg = '#010203' })
assert_true(clear_last_fg_ok, clear_last_fg_err or 'clear-last fg runtime apply failed')
local clear_last_unset_ok, clear_last_unset_err =
  detail_values.apply_runtime(nil, clear_last_field_name, { fg = vim.NIL })
assert_true(clear_last_unset_ok, clear_last_unset_err or 'clear-last fg unset failed')
assert_equal(
  overrides.get_runtime_group(clear_last_field_name),
  'smoke-clear-last',
  'clearing last override field dropped selected runtime group'
)
assert_equal(next(overrides.get(clear_last_field_name)), nil, 'clearing last field left override fields behind')
local clear_last_save_ok, clear_last_save_err = detail_values.save(nil, clear_last_field_name)
assert_true(clear_last_save_ok, clear_last_save_err or 'clear-last group-only save failed')
local clear_last_loaded = storage.load(persist_dir)
assert_equal(
  clear_last_loaded.groups[clear_last_field_name],
  'smoke-clear-last',
  'clear-last group-only save did not persist selected group'
)

local cleanup_instance = require('hlcraft.ui.instance').new('cleanup-smoke')
results_state.open_unsaved_prompt(cleanup_instance, result_name)
local cleanup_prompt_win = cleanup_instance.state.unsaved_prompt.win
local cleanup_prompt_buf = cleanup_instance.state.unsaved_prompt.buf
assert_true(cleanup_prompt_win ~= nil, 'cleanup prompt was not opened')
assert_true(cleanup_prompt_buf ~= nil, 'cleanup prompt buffer was not created')
cleanup_instance:cleanup()
assert_true(not vim.api.nvim_win_is_valid(cleanup_prompt_win), 'cleanup left unsaved prompt window open')
assert_true(not vim.api.nvim_buf_is_valid(cleanup_prompt_buf), 'cleanup left unsaved prompt buffer alive')
assert_true(cleanup_instance.state.unsaved_prompt.win == nil, 'cleanup did not reset unsaved prompt window state')
assert_true(cleanup_instance.state.unsaved_prompt.buf == nil, 'cleanup did not reset unsaved prompt buffer state')

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
