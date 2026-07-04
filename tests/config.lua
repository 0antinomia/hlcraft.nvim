local h = require('tests.helpers')
local scope = 'hlcraft config'

local config = require('hlcraft.config')

for _, case in ipairs({
  { value = 'bad', message = 'non-table config was accepted' },
  { value = { unknown = true }, message = 'unknown config key was accepted' },
  { value = { persist_dir = '' }, message = 'empty persist_dir was accepted' },
  { value = { threshold = -1 }, message = 'negative threshold was accepted' },
  { value = { threshold = 0 / 0, debounce_ms = math.huge }, message = 'non-finite numeric config was accepted' },
  { value = { include_sp_in_color_search = 'yes' }, message = 'non-boolean color search config was accepted' },
  { value = { from_none = { scope = 'bad' } }, message = 'invalid from_none scope was accepted' },
  { value = { reapply_events = { events = { '' } } }, message = 'empty reapply event was accepted' },
  { value = { reapply_events = { events = { { event = '' } } } }, message = 'empty table event was accepted' },
  { value = { dynamic = { enabled = 'yes', interval_ms = 0 } }, message = 'invalid dynamic config was accepted' },
  { value = { preview_key = true }, message = 'preview_key=true was accepted' },
  { value = { preview_key = '' }, message = 'blank preview_key was accepted' },
}) do
  local ok = config.validate(case.value)
  h.assert_true(not ok, case.message, scope)
end

local invalid_setup_ok = pcall(config.setup, { threshold = 0 / 0 })
h.assert_true(not invalid_setup_ok, 'config.setup accepted invalid config directly', scope)

local valid_ok, valid_err = config.validate({
  from_none = { enabled = true, scope = 'core' },
  threshold = 42,
  include_sp_in_color_search = true,
  persist_dir = vim.fn.stdpath('cache') .. '/hlcraft-config-test',
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
      { event = 'SessionLoadPost', pattern = '*', once = false },
    },
  },
  dynamic = { enabled = true, interval_ms = 120 },
  debounce_ms = 0,
  preview_key = false,
})
h.assert_true(valid_ok, valid_err or 'valid config was rejected', scope)

local defaults = config.setup({})
h.assert_equal(defaults.from_none.enabled, false, 'default from_none.enabled changed', scope)
h.assert_equal(defaults.from_none.scope, 'extended', 'default from_none.scope changed', scope)
h.assert_equal(defaults.reapply_events.enabled, true, 'default reapply_events.enabled changed', scope)
h.assert_equal(defaults.reapply_events.events[1], 'ColorScheme', 'default reapply event changed', scope)
h.assert_equal(defaults.dynamic.enabled, false, 'default dynamic.enabled changed', scope)
h.assert_equal(defaults.dynamic.interval_ms, 80, 'default dynamic interval changed', scope)

local merged = config.setup({
  from_none = true,
  reapply_events = false,
  dynamic = { enabled = true, interval_ms = 120 },
  debounce_ms = 0,
  preview_key = false,
})
h.assert_equal(merged.from_none.enabled, true, 'boolean from_none did not enable option', scope)
h.assert_equal(merged.from_none.scope, 'extended', 'boolean from_none did not keep default scope', scope)
h.assert_equal(merged.reapply_events.enabled, false, 'boolean reapply_events=false did not disable replay', scope)
h.assert_equal(merged.dynamic.enabled, true, 'dynamic.enabled override was not preserved', scope)
h.assert_equal(merged.dynamic.interval_ms, 120, 'dynamic.interval_ms override was not preserved', scope)
h.assert_equal(merged.debounce_ms, 0, 'debounce_ms override was not preserved', scope)
h.assert_equal(merged.preview_key, false, 'preview_key override was not preserved', scope)

config.setup({})

print('hlcraft config: OK')
