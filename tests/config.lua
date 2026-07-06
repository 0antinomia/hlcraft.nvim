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
    value = { search = { unknown = true } },
    error = 'unknown config key: "search.unknown"',
    message = 'unknown search key was accepted',
  },
  {
    value = { persistence = { unknown = true } },
    error = 'unknown config key: "persistence.unknown"',
    message = 'unknown persistence key was accepted',
  },
  {
    value = { persistence = { dir = '' } },
    error = 'persistence.dir: must be a non-empty string',
    message = 'empty persistence dir was accepted',
  },
  {
    value = { search = { threshold = -1 } },
    error = 'search.threshold: must be between 0 and 1000',
    message = 'negative search threshold was accepted',
  },
  {
    value = { search = { threshold = 1001 } },
    error = 'search.threshold: must be between 0 and 1000',
    message = 'excessive search threshold was accepted',
  },
  {
    value = { search = { threshold = 0 / 0, debounce_ms = math.huge } },
    error = 'search.threshold: must be finite',
    message = 'non-finite numeric search config was accepted',
  },
  {
    value = { search = { debounce_ms = -1 } },
    error = 'search.debounce_ms: must be >= 0',
    message = 'negative search debounce was accepted',
  },
  {
    value = { search = { include_sp = 'yes' } },
    error = 'search.include_sp: must be boolean, got string',
    message = 'non-boolean color search config was accepted',
  },
  {
    value = { transparent = true },
    error = 'transparent: must be a table, got boolean',
    message = 'boolean transparent config was accepted',
  },
  {
    value = { transparent = { scope = 'bad' } },
    error = 'transparent.scope: must be "core" or "extended", got "bad"',
    message = 'invalid transparent scope was accepted',
  },
  {
    value = { transparent = { unknown = true } },
    error = 'unknown config key: "transparent.unknown"',
    message = 'unknown transparent key was accepted',
  },
  {
    value = { persistence = { reapply_events = false } },
    error = 'persistence.reapply_events: must be a table, got boolean',
    message = 'boolean persistence reapply_events was accepted',
  },
  {
    value = { persistence = { reapply_events = { unknown = true } } },
    error = 'unknown config key: "persistence.reapply_events.unknown"',
    message = 'unknown persistence reapply_events key was accepted',
  },
  {
    value = { persistence = { reapply_events = { events = { ColorScheme = true } } } },
    error = 'persistence.reapply_events.events: must be a sequence',
    message = 'non-sequence reapply events were accepted',
  },
  {
    value = { persistence = { reapply_events = { events = { '' } } } },
    error = 'persistence.reapply_events.events[1]: must be a non-empty string',
    message = 'empty reapply event was accepted',
  },
  {
    value = { persistence = { reapply_events = { events = { '   ' } } } },
    error = 'persistence.reapply_events.events[1]: must be a non-empty string',
    message = 'blank reapply event was accepted',
  },
  {
    value = { persistence = { reapply_events = { events = { { event = '' } } } } },
    error = 'persistence.reapply_events.events[1].event: must be a non-empty string',
    message = 'empty table event was accepted',
  },
  {
    value = { persistence = { reapply_events = { events = { { event = '   ' } } } } },
    error = 'persistence.reapply_events.events[1].event: must be a non-empty string',
    message = 'blank table event was accepted',
  },
  {
    value = { persistence = { reapply_events = { events = { { event = 'ColorScheme', unknown = true } } } } },
    error = 'unknown config key: "persistence.reapply_events.events[1].unknown"',
    message = 'unknown reapply event key was accepted',
  },
  {
    value = { persistence = { reapply_events = { events = { { event = 'ColorScheme', pattern = '   ' } } } } },
    error = 'persistence.reapply_events.events[1].pattern: must be a non-empty string',
    message = 'blank reapply event pattern was accepted',
  },
  {
    value = { dynamic = { interval_ms = 0 } },
    error = 'dynamic.interval_ms: must be between 16 and 1000',
    message = 'low dynamic interval was accepted',
  },
  {
    value = { dynamic = { interval_ms = 1001 } },
    error = 'dynamic.interval_ms: must be between 16 and 1000',
    message = 'high dynamic interval was accepted',
  },
  {
    value = { dynamic = { unknown = true } },
    error = 'unknown config key: "dynamic.unknown"',
    message = 'unknown dynamic config key was accepted',
  },
  {
    value = { keymaps = { unknown = true } },
    error = 'unknown config key: "keymaps.unknown"',
    message = 'unknown keymaps config key was accepted',
  },
  {
    value = { keymaps = { preview = true } },
    error = 'keymaps.preview: must be false or table, got boolean',
    message = 'invalid preview keymap config was accepted',
  },
  {
    value = { keymaps = { preview = { lhs = '' } } },
    error = 'keymaps.preview.lhs: must be a non-empty string',
    message = 'blank preview keymap lhs was accepted',
  },
  {
    value = { keymaps = { preview = { lhs = 'z', mode = 'i' } } },
    error = 'keymaps.preview.mode: must be "n"',
    message = 'non-normal preview keymap mode was accepted',
  },
  {
    value = { keymaps = { preview = { lhs = 'z', opts = false } } },
    error = 'keymaps.preview.opts: must be a table, got boolean',
    message = 'non-table preview keymap opts were accepted',
  },
  {
    value = { keymaps = { preview = { lhs = 'z', opts = { buffer = true } } } },
    error = 'unknown config key: "keymaps.preview.opts.buffer"',
    message = 'unknown preview keymap option was accepted',
  },
}) do
  assert_invalid(case.value, case.error, case.message)
end

local invalid_setup_ok, invalid_setup_err = pcall(config.setup, { search = { threshold = 0 / 0 } })
h.assert_true(not invalid_setup_ok, 'config.setup accepted invalid config directly', scope)
h.assert_true(
  tostring(invalid_setup_err):find('search.threshold: must be finite', 1, true) ~= nil,
  'config.setup reported the wrong validation error',
  scope
)

local valid_ok, valid_err = config.validate({
  transparent = { enabled = true, scope = 'core' },
  search = {
    threshold = 42,
    include_sp = true,
    debounce_ms = 0,
  },
  persistence = {
    dir = vim.fn.stdpath('cache') .. '/hlcraft-config-test',
    reapply_events = {
      enabled = true,
      events = {
        'ColorScheme',
        { event = 'SessionLoadPost', pattern = '*', once = false },
      },
    },
  },
  dynamic = { interval_ms = 120 },
  keymaps = {
    preview = {
      lhs = '<leader>hp',
      mode = 'n',
      opts = {
        desc = 'preview highlight',
        silent = false,
        nowait = false,
      },
    },
  },
})
h.assert_true(valid_ok, valid_err or 'valid config was rejected', scope)

local function normalize_with(overrides)
  return schema.normalize(vim.tbl_deep_extend('force', vim.deepcopy(schema.defaults), overrides))
end

local fractional_dynamic = normalize_with({ dynamic = { interval_ms = 120.9 } })
h.assert_equal(fractional_dynamic.dynamic.interval_ms, 120, 'dynamic interval did not floor fractional values', scope)
local trimmed_preview_keymap = normalize_with({
  keymaps = {
    preview = {
      lhs = ' zz ',
      mode = ' n ',
      opts = {
        desc = ' preview result ',
      },
    },
  },
})
h.assert_equal(trimmed_preview_keymap.keymaps.preview.lhs, 'zz', 'preview keymap lhs did not trim', scope)
h.assert_equal(trimmed_preview_keymap.keymaps.preview.mode, 'n', 'preview keymap mode did not trim', scope)
h.assert_equal(
  trimmed_preview_keymap.keymaps.preview.opts.desc,
  'preview result',
  'preview keymap desc did not trim',
  scope
)
local trimmed_reapply_events = normalize_with({
  persistence = {
    reapply_events = {
      events = {
        ' ColorScheme ',
        { event = ' SessionLoadPost ', pattern = ' * ', once = true },
      },
    },
  },
})
h.assert_equal(
  trimmed_reapply_events.persistence.reapply_events.events[1],
  'ColorScheme',
  'string reapply event did not trim',
  scope
)
h.assert_equal(
  trimmed_reapply_events.persistence.reapply_events.events[2].event,
  'SessionLoadPost',
  'table reapply event did not trim',
  scope
)
h.assert_equal(
  trimmed_reapply_events.persistence.reapply_events.events[2].pattern,
  '*',
  'reapply event pattern did not trim',
  scope
)
local invalid_normalize_ok = pcall(
  schema.normalize,
  vim.tbl_extend('force', vim.deepcopy(schema.defaults), {
    keymaps = {
      preview = true,
    },
  })
)
h.assert_true(not invalid_normalize_ok, 'config normalization accepted an invalid preview keymap', scope)

local defaults = config.setup({})
h.assert_equal(defaults.transparent.enabled, false, 'default transparent.enabled changed', scope)
h.assert_equal(defaults.transparent.scope, 'extended', 'default transparent.scope changed', scope)
h.assert_equal(defaults.search.threshold, 100, 'default search.threshold changed', scope)
h.assert_equal(defaults.search.include_sp, false, 'default search.include_sp changed', scope)
h.assert_equal(defaults.search.debounce_ms, 100, 'default search.debounce_ms changed', scope)
h.assert_equal(defaults.persistence.reapply_events.enabled, true, 'default persistence reapply enabled changed', scope)
h.assert_equal(defaults.persistence.reapply_events.events[1], 'ColorScheme', 'default reapply event changed', scope)
h.assert_equal(defaults.dynamic.interval_ms, 80, 'default dynamic interval changed', scope)
h.assert_equal(defaults.keymaps.preview.lhs, 'z', 'default preview keymap lhs changed', scope)
h.assert_equal(defaults.keymaps.preview.mode, 'n', 'default preview keymap mode changed', scope)
h.assert_equal(
  defaults.keymaps.preview.opts.desc,
  'hlcraft flash current highlight',
  'default preview desc changed',
  scope
)

local merged = config.setup({
  transparent = {
    enabled = true,
  },
  persistence = {
    reapply_events = {
      enabled = false,
    },
  },
  search = {
    debounce_ms = 0,
  },
  dynamic = { interval_ms = 120 },
  keymaps = {
    preview = false,
  },
})
h.assert_equal(merged.transparent.enabled, true, 'transparent.enabled override was not preserved', scope)
h.assert_equal(merged.transparent.scope, 'extended', 'transparent override did not keep default scope', scope)
h.assert_equal(
  merged.persistence.reapply_events.enabled,
  false,
  'persistence reapply override was not preserved',
  scope
)
h.assert_equal(merged.dynamic.interval_ms, 120, 'dynamic.interval_ms override was not preserved', scope)
h.assert_equal(merged.search.debounce_ms, 0, 'search.debounce_ms override was not preserved', scope)
h.assert_equal(merged.keymaps.preview, false, 'preview keymap override was not preserved', scope)

config.setup({})

print('hlcraft config: OK')
