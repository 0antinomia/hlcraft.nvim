local h = require('tests.helpers')
local scope = 'hlcraft override entries'

local override_entries = require('hlcraft.core.override_entries')

local normalized, normalize_err = override_entries.normalize({
  fg = '#ABCDEF',
  bold = false,
  blend = '42.9',
})
h.assert_true(normalized ~= nil, normalize_err or 'valid override entry did not normalize', scope)
h.assert_equal(normalized.fg, '#abcdef', 'entry color did not normalize', scope)
h.assert_equal(normalized.bold, false, 'entry style false did not normalize', scope)
h.assert_equal(normalized.blend, 42, 'entry blend did not normalize', scope)

local invalid_entry, invalid_entry_err = override_entries.normalize(false, { label = 'test entry' })
h.assert_true(invalid_entry == nil, 'override entry accepted a non-table value', scope)
h.assert_equal(invalid_entry_err, 'test entry must be a table', 'non-table entry error changed', scope)

local unknown_entry, unknown_entry_err = override_entries.normalize({ unknown = true }, { label = 'test entry' })
h.assert_true(unknown_entry == nil, 'override entry accepted an unknown field', scope)
h.assert_equal(unknown_entry_err, 'test entry has unsupported field: unknown', 'unknown field error changed', scope)

local invalid_opts_ok = pcall(override_entries.normalize, {}, false)
h.assert_true(not invalid_opts_ok, 'override entry accepted non-table options', scope)
local unknown_opts_ok = pcall(override_entries.normalize, {}, { unknown = true })
h.assert_true(not unknown_opts_ok, 'override entry accepted unknown options', scope)
local invalid_label_ok = pcall(override_entries.normalize, {}, { label = '' })
h.assert_true(not invalid_label_ok, 'override entry accepted an empty label', scope)
local blank_label_ok = pcall(override_entries.normalize, {}, { label = '   ' })
h.assert_true(not blank_label_ok, 'override entry accepted a blank label', scope)
local invalid_compact_ok = pcall(override_entries.normalize, {}, { compact_dynamic = 'yes' })
h.assert_true(not invalid_compact_ok, 'override entry accepted non-boolean compact option', scope)

local compacted_dynamic, compact_err = override_entries.normalize({
  dynamic = {
    fg = {
      version = 1,
      duration = 2000,
      loop = 'repeat',
      phase = 0,
      interpolation = 'linear',
      timeline = {
        { at = 0, color = 'base' },
      },
      transforms = {},
    },
  },
}, { compact_dynamic = true })
h.assert_true(compacted_dynamic ~= nil, compact_err or 'compact dynamic entry did not normalize', scope)
h.assert_true(compacted_dynamic.dynamic.fg.duration == nil, 'compact dynamic kept default duration', scope)
h.assert_true(compacted_dynamic.dynamic.fg.transforms == nil, 'compact dynamic kept empty transforms', scope)

print('hlcraft override entries: OK')
