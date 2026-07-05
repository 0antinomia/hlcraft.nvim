local h = require('tests.helpers')
local scope = 'hlcraft persistence schema'

local schema = require('hlcraft.persistence.schema')

local normalized_entry, normalize_err = schema.normalize_entry('Normal', {
  fg = '#AABBCC',
  dynamic = {
    fg = {
      version = 1,
      timeline = {
        { at = 0, color = 'base' },
      },
    },
  },
})
h.assert_true(normalized_entry ~= nil, normalize_err or 'valid schema entry did not normalize', scope)
h.assert_equal(normalized_entry.fg, '#aabbcc', 'schema did not normalize color field', scope)
h.assert_true(type(normalized_entry.dynamic.fg) == 'table', 'schema did not normalize dynamic field', scope)

local unknown_entry, unknown_err = schema.normalize_entry('Normal', { unknown = true })
h.assert_true(unknown_entry == nil, 'schema accepted an unknown entry field', scope)
h.assert_equal(unknown_err, 'Highlight Normal has unsupported field: unknown', 'unknown entry error changed', scope)

local invalid_field_entry, invalid_field_err = schema.normalize_entry('Normal', { fg = 123 })
h.assert_true(invalid_field_entry == nil, 'schema accepted an invalid entry field', scope)
h.assert_equal(
  invalid_field_err,
  'Highlight Normal has invalid fg: Color must be a string or nil, got number',
  'invalid entry field error changed',
  scope
)

local nil_entry_ok = pcall(schema.normalize_entry, 'Normal', nil)
h.assert_true(not nil_entry_ok, 'schema accepted nil entry', scope)
local bad_opts_ok = pcall(schema.normalize_entry, 'Normal', {}, false)
h.assert_true(not bad_opts_ok, 'schema accepted non-table normalize options', scope)
local unknown_opts_ok = pcall(schema.normalize_entry, 'Normal', {}, { compact = true })
h.assert_true(not unknown_opts_ok, 'schema accepted unknown normalize options', scope)
local bad_compact_option_ok = pcall(schema.normalize_entry, 'Normal', {}, { compact_dynamic = 'yes' })
h.assert_true(not bad_compact_option_ok, 'schema accepted non-boolean compact option', scope)

local data = {
  entries = {
    Normal = {
      fg = '#AABBCC',
    },
  },
  groups = {
    Normal = 'main',
  },
  sections = {
    main = {
      Normal = {
        fg = '#AABBCC',
      },
    },
  },
}
local normalized_data = schema.normalize_loaded_data(data)
h.assert_equal(normalized_data.entries.Normal.fg, '#aabbcc', 'loaded entry did not normalize', scope)
h.assert_equal(
  normalized_data.sections.main.Normal.fg,
  '#aabbcc',
  'loaded section entry did not reuse normalized entry',
  scope
)

local invalid_loaded_ok, invalid_loaded_err = pcall(schema.normalize_loaded_data, {
  entries = {
    Invalid = {
      fg = 123,
    },
  },
  groups = {
    Invalid = 'main',
  },
  sections = {
    main = {
      Invalid = {
        fg = 123,
      },
    },
  },
})
h.assert_true(not invalid_loaded_ok, 'schema accepted invalid loaded entry fields', scope)
h.assert_true(
  tostring(invalid_loaded_err):find('Highlight Invalid has invalid fg', 1, true) ~= nil,
  'invalid loaded entry error changed',
  scope
)

for _, case in ipairs({
  {
    label = 'data',
    value = nil,
  },
  {
    label = 'entries',
    value = {
      groups = {},
      sections = {},
    },
  },
  {
    label = 'groups',
    value = {
      entries = {},
      sections = {},
    },
  },
  {
    label = 'sections',
    value = {
      entries = {},
      groups = {},
    },
  },
  {
    label = 'section entries',
    value = {
      entries = {},
      groups = {},
      sections = {
        main = false,
      },
    },
  },
}) do
  local ok = pcall(schema.normalize_loaded_data, case.value)
  h.assert_true(not ok, ('schema accepted invalid loaded %s'):format(case.label), scope)
end

local nil_entries_ok = pcall(schema.normalize_entries, nil)
h.assert_true(not nil_entries_ok, 'schema accepted nil entries', scope)

local invalid_entries, invalid_entries_err = schema.normalize_entries({
  Normal = {
    unknown = true,
  },
})
h.assert_true(invalid_entries == nil, 'schema accepted invalid persisted entries', scope)
h.assert_equal(
  invalid_entries_err,
  'Highlight Normal has unsupported field: unknown',
  'invalid persisted entries error changed',
  scope
)

print('hlcraft persistence schema: OK')
