local h = require('tests.helpers')
local scope = 'hlcraft ui raw dynamic'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local engine = require('hlcraft.engine.service')
local raw_dynamic = require('hlcraft.ui.raw_dynamic')

local name = 'HlcraftUiRawDynamicNormal'
local persist_dir = h.temp_dir('hlcraft-ui-raw-dynamic')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, name, { fg = '#101010' })
engine.set_group(name, 'ui-raw-dynamic')
local dynamic_ok, dynamic_err = engine.set_dynamic(name, 'fg', {
  version = 1,
  preset = 'manual',
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
    { at = 1, color = '#ffffff' },
  },
})
h.assert_true(dynamic_ok, dynamic_err or 'set dynamic failed', scope)

local result = { name = name }
local instance = { state = {} }

local missing_raw_instance_ok = pcall(raw_dynamic.close, nil)
h.assert_true(not missing_raw_instance_ok, 'raw dynamic close accepted missing instance', scope)
local missing_raw_open_instance_ok = pcall(raw_dynamic.open, nil, result, 'fg')
h.assert_true(not missing_raw_open_instance_ok, 'raw dynamic open accepted missing instance', scope)
local invalid_raw_state_ok = pcall(raw_dynamic.close, {
  state = {
    raw_dynamic = true,
  },
})
h.assert_true(not invalid_raw_state_ok, 'raw dynamic close accepted invalid state schema', scope)
local invalid_raw_buf_ok = pcall(raw_dynamic.close, {
  state = {
    raw_dynamic = {
      buf = false,
    },
  },
})
h.assert_true(not invalid_raw_buf_ok, 'raw dynamic close accepted invalid buffer handle state', scope)
local invalid_raw_win_ok = pcall(raw_dynamic.close, {
  state = {
    raw_dynamic = {
      win = false,
    },
  },
})
h.assert_true(not invalid_raw_win_ok, 'raw dynamic close accepted invalid window handle state', scope)
local invalid_raw_result_ok = pcall(raw_dynamic.open, {
  state = {},
}, {}, 'fg')
h.assert_true(not invalid_raw_result_ok, 'raw dynamic open accepted a nameless result', scope)
local invalid_raw_field_ok = pcall(raw_dynamic.open, {
  state = {},
}, result, false)
h.assert_true(not invalid_raw_field_ok, 'raw dynamic open accepted invalid field', scope)

local preserved_raw_buf = vim.api.nvim_create_buf(false, true)
local preserved_raw_win = vim.api.nvim_open_win(preserved_raw_buf, false, {
  relative = 'editor',
  style = 'minimal',
  width = 1,
  height = 1,
  row = 0,
  col = 0,
})
instance.state.raw_dynamic = {
  buf = preserved_raw_buf,
  win = preserved_raw_win,
}
local inactive_raw_ok, inactive_raw_err = raw_dynamic.open(instance, result, 'bg')
h.assert_true(not inactive_raw_ok, 'raw dynamic open accepted inactive dynamic field', scope)
h.assert_equal(inactive_raw_err, 'No dynamic color field is active', 'inactive raw dynamic error changed', scope)
h.assert_true(vim.api.nvim_win_is_valid(preserved_raw_win), 'failed raw dynamic open closed existing window', scope)
h.assert_true(vim.api.nvim_buf_is_valid(preserved_raw_buf), 'failed raw dynamic open deleted existing buffer', scope)
h.assert_equal(instance.state.raw_dynamic.win, preserved_raw_win, 'failed raw dynamic open changed raw state', scope)
raw_dynamic.close(instance)

local original_columns = vim.o.columns
local original_lines = vim.o.lines
local tiny_raw_instance = {
  state = {},
}
local tiny_raw_ok, tiny_raw_err = xpcall(function()
  vim.o.columns = 30
  vim.o.lines = 10
  local open_ok, open_err = raw_dynamic.open(tiny_raw_instance, result, 'fg')
  h.assert_true(open_ok, open_err or 'tiny raw dynamic editor did not open', scope)
  local raw_state = tiny_raw_instance.state.raw_dynamic
  h.assert_true(
    vim.api.nvim_win_get_width(raw_state.win) <= vim.o.columns - 2,
    'tiny raw dynamic editor exceeded available width',
    scope
  )
  h.assert_true(
    vim.api.nvim_win_get_height(raw_state.win) <= math.max(1, vim.o.lines - 4),
    'tiny raw dynamic editor exceeded available height',
    scope
  )
end, debug.traceback)
raw_dynamic.close(tiny_raw_instance)
vim.o.columns = original_columns
vim.o.lines = original_lines
if not tiny_raw_ok then
  error(tiny_raw_err, 0)
end

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui raw dynamic: OK')
