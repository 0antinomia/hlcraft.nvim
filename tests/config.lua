local h = require('tests.helpers')
local scope = 'hlcraft config'

local config = require('hlcraft.config')
local schema = require('hlcraft.config.schema')

local function assert_invalid(value, expected_error, message)
  local ok, err = config.validate(value)
  h.assert_true(not ok, message, scope)
  h.assert_true(
    tostring(err):find(expected_error, 1, true) ~= nil,
    ('%s reported the wrong error (expected %s, got %s)'):format(message, vim.inspect(expected_error), vim.inspect(err)),
    scope
  )
end

for _, case in ipairs({
  { value = 'bad', error = 'hlcraft config must be a table, got string', message = 'non-table config was accepted' },
  { value = { unknown = true }, error = 'unknown config key: "unknown"', message = 'unknown config key was accepted' },
  {
    value = { persist_dir = '' },
    error = 'persist_dir: must be a non-empty string',
    message = 'empty persist_dir was accepted',
  },
  {
    value = { threshold = -1 },
    error = 'threshold: must be between 0 and 1000',
    message = 'negative threshold was accepted',
  },
  {
    value = { threshold = 0 / 0, debounce_ms = math.huge },
    error = 'threshold: must be finite',
    message = 'non-finite numeric config was accepted',
  },
  {
    value = { include_sp_in_color_search = 'yes' },
    error = 'include_sp_in_color_search: must be boolean, got string',
    message = 'non-boolean color search config was accepted',
  },
  {
    value = { from_none = { scope = 'bad' } },
    error = 'from_none.scope: must be "core" or "extended", got "bad"',
    message = 'invalid from_none scope was accepted',
  },
  {
    value = { from_none = { unknown = true } },
    error = 'unknown config key: "from_none.unknown"',
    message = 'unknown from_none key was accepted',
  },
  {
    value = { reapply_events = { unknown = true } },
    error = 'unknown config key: "reapply_events.unknown"',
    message = 'unknown reapply_events key was accepted',
  },
  {
    value = { reapply_events = { events = { '' } } },
    error = 'reapply_events.events[1]: must be a non-empty string',
    message = 'empty reapply event was accepted',
  },
  {
    value = { reapply_events = { events = { '   ' } } },
    error = 'reapply_events.events[1]: must be a non-empty string',
    message = 'blank reapply event was accepted',
  },
  {
    value = { reapply_events = { events = { { event = '' } } } },
    error = 'reapply_events.events[1].event: must be a non-empty string',
    message = 'empty table event was accepted',
  },
  {
    value = { reapply_events = { events = { { event = '   ' } } } },
    error = 'reapply_events.events[1].event: must be a non-empty string',
    message = 'blank table event was accepted',
  },
  {
    value = { reapply_events = { events = { { event = 'ColorScheme', unknown = true } } } },
    error = 'unknown config key: "reapply_events.events[1].unknown"',
    message = 'unknown reapply event key was accepted',
  },
  {
    value = { dynamic = { enabled = 'yes', interval_ms = 0 } },
    error = 'dynamic.enabled: must be boolean, got string',
    message = 'invalid dynamic config was accepted',
  },
  {
    value = { dynamic = { unknown = true } },
    error = 'unknown config key: "dynamic.unknown"',
    message = 'unknown dynamic config key was accepted',
  },
  {
    value = { preview_key = true },
    error = 'preview_key: boolean value must be false when used',
    message = 'preview_key=true was accepted',
  },
  {
    value = { preview_key = 123 },
    error = 'preview_key: must be a string or boolean, got number',
    message = 'numeric preview_key was accepted',
  },
  {
    value = { preview_key = '' },
    error = 'preview_key: must be a non-empty string when provided',
    message = 'blank preview_key was accepted',
  },
}) do
  assert_invalid(case.value, case.error, case.message)
end

local invalid_setup_ok, invalid_setup_err = pcall(config.setup, { threshold = 0 / 0 })
h.assert_true(not invalid_setup_ok, 'config.setup accepted invalid config directly', scope)
h.assert_true(
  tostring(invalid_setup_err):find('threshold: must be finite', 1, true) ~= nil,
  'config.setup reported the wrong validation error',
  scope
)

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

local function normalize_with(overrides)
  return schema.normalize(vim.tbl_deep_extend('force', vim.deepcopy(schema.defaults), overrides))
end

local low_dynamic = normalize_with({ dynamic = { interval_ms = 1 } })
h.assert_equal(low_dynamic.dynamic.interval_ms, 16, 'dynamic interval did not clamp to minimum', scope)
local high_dynamic = normalize_with({ dynamic = { interval_ms = 5000 } })
h.assert_equal(high_dynamic.dynamic.interval_ms, 1000, 'dynamic interval did not clamp to maximum', scope)
local low_threshold = normalize_with({ threshold = -1 })
h.assert_equal(low_threshold.threshold, 0, 'threshold did not clamp to minimum', scope)
local high_threshold = normalize_with({ threshold = 1001 })
h.assert_equal(high_threshold.threshold, 1000, 'threshold did not clamp to maximum', scope)
local low_debounce = normalize_with({ debounce_ms = -1 })
h.assert_equal(low_debounce.debounce_ms, 0, 'debounce_ms did not clamp to minimum', scope)
local non_finite_numbers = normalize_with({ threshold = 0 / 0, debounce_ms = math.huge })
h.assert_equal(non_finite_numbers.threshold, 100, 'non-finite threshold did not fall back to default', scope)
h.assert_equal(non_finite_numbers.debounce_ms, 100, 'non-finite debounce_ms did not fall back to default', scope)
local trimmed_preview_key = normalize_with({ preview_key = ' zz ' })
h.assert_equal(trimmed_preview_key.preview_key, 'zz', 'preview_key did not trim', scope)
local invalid_preview_key = normalize_with({ preview_key = 123 })
h.assert_equal(invalid_preview_key.preview_key, 'z', 'invalid preview_key did not fall back to default', scope)

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
