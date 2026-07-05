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
local nil_entry_name_ok = pcall(schema.normalize_entry, nil, {})
h.assert_true(not nil_entry_name_ok, 'schema accepted nil entry name', scope)
local empty_entry_name_ok = pcall(schema.normalize_entry, '   ', {})
h.assert_true(not empty_entry_name_ok, 'schema accepted empty entry name', scope)
local spaced_entry_name_ok = pcall(schema.normalize_entry, 'Bad Name', {})
h.assert_true(not spaced_entry_name_ok, 'schema accepted whitespace in entry name', scope)
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

local normalized_group_data = schema.normalize_loaded_data({
  entries = {
    Spaced = {
      fg = '#AABBCC',
    },
  },
  groups = {
    Spaced = ' main ',
  },
  sections = {
    [' main '] = {
      Spaced = {
        fg = '#AABBCC',
      },
    },
  },
})
h.assert_equal(normalized_group_data.groups.Spaced, 'main', 'loaded group name did not normalize', scope)
h.assert_true(normalized_group_data.sections[' main '] == nil, 'loaded section kept unnormalized key', scope)
h.assert_equal(
  normalized_group_data.sections.main.Spaced.fg,
  '#aabbcc',
  'loaded normalized section entry changed',
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

local mismatched_loaded_entry_ok = pcall(schema.normalize_loaded_data, {
  entries = {
    Diverged = {
      fg = '#101010',
    },
  },
  groups = {
    Diverged = 'main',
  },
  sections = {
    main = {
      Diverged = {
        fg = '#202020',
      },
    },
  },
})
h.assert_true(not mismatched_loaded_entry_ok, 'schema accepted divergent loaded section entry', scope)

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

for _, case in ipairs({
  {
    label = 'group without entry',
    value = {
      entries = {},
      groups = {
        OrphanGroup = 'main',
      },
      sections = {
        main = {},
      },
    },
  },
  {
    label = 'entry without group',
    value = {
      entries = {
        OrphanEntry = {
          fg = '#101010',
        },
      },
      groups = {},
      sections = {
        main = {
          OrphanEntry = {
            fg = '#101010',
          },
        },
      },
    },
  },
  {
    label = 'entry missing from section',
    value = {
      entries = {
        MissingSectionEntry = {
          fg = '#101010',
        },
      },
      groups = {
        MissingSectionEntry = 'main',
      },
      sections = {
        main = {},
      },
    },
  },
  {
    label = 'section group mismatch',
    value = {
      entries = {
        MismatchedSection = {
          fg = '#101010',
        },
      },
      groups = {
        MismatchedSection = 'main',
      },
      sections = {
        main = {
          MismatchedSection = {
            fg = '#101010',
          },
        },
        other = {
          MismatchedSection = {
            fg = '#101010',
          },
        },
      },
    },
  },
}) do
  local ok = pcall(schema.normalize_loaded_data, case.value)
  h.assert_true(not ok, ('schema accepted loaded %s'):format(case.label), scope)
end

local spaced_loaded_name_ok = pcall(schema.normalize_loaded_data, {
  entries = {
    ['Bad Name'] = {
      fg = '#101010',
    },
  },
  groups = {
    ['Bad Name'] = 'main',
  },
  sections = {
    main = {
      ['Bad Name'] = {
        fg = '#101010',
      },
    },
  },
})
h.assert_true(not spaced_loaded_name_ok, 'schema accepted whitespace in loaded highlight name', scope)

local nil_entries_ok = pcall(schema.normalize_entries, nil)
h.assert_true(not nil_entries_ok, 'schema accepted nil entries', scope)
local invalid_entries_name_ok = pcall(schema.normalize_entries, {
  [1] = {},
})
h.assert_true(not invalid_entries_name_ok, 'schema accepted invalid persisted entry name', scope)
local spaced_entries_name_ok = pcall(schema.normalize_entries, {
  ['Bad Name'] = {},
})
h.assert_true(not spaced_entries_name_ok, 'schema accepted whitespace in persisted entry name', scope)

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
