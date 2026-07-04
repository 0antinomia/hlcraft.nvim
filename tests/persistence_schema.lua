local h = require('tests.helpers')
local scope = 'hlcraft persistence schema'

local schema = require('hlcraft.persistence.schema')

local normalized_entry = schema.normalize_entry({
  fg = '#AABBCC',
  unknown = true,
  dynamic = {
    fg = {
      version = 1,
      timeline = {
        { at = 0, color = 'base' },
      },
    },
  },
})
h.assert_equal(normalized_entry.fg, '#aabbcc', 'schema did not normalize color field', scope)
h.assert_true(normalized_entry.unknown == nil, 'schema kept unknown load-side field', scope)
h.assert_true(type(normalized_entry.dynamic.fg) == 'table', 'schema did not normalize dynamic field', scope)

local nil_entry_ok = pcall(schema.normalize_entry, nil)
h.assert_true(not nil_entry_ok, 'schema accepted nil entry', scope)
local bad_opts_ok = pcall(schema.normalize_entry, {}, false)
h.assert_true(not bad_opts_ok, 'schema accepted non-table normalize options', scope)
local bad_compact_option_ok = pcall(schema.normalize_entry, {}, { compact_dynamic = 'yes' })
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
      Invalid = {
        fg = 123,
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
h.assert_equal(next(normalized_data.sections.main.Invalid), nil, 'invalid loaded section fields leaked', scope)

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
local nil_strict_entries_ok = pcall(schema.normalize_entries_strict, nil)
h.assert_true(not nil_strict_entries_ok, 'schema accepted nil strict entries', scope)

print('hlcraft persistence schema: OK')
