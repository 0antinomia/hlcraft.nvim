local h = require('tests.helpers')
local scope = 'hlcraft persistence codec'

local codec = require('hlcraft.persistence.codec')
local parser = require('hlcraft.persistence.codec.parser')
local util = require('hlcraft.persistence.codec.util')

local function assert_invalid_entry(line)
  local name, entry = parser.entry_line(line)
  h.assert_true(name == nil and entry == nil, ('invalid codec line parsed: %s'):format(line), scope)
end

local function assert_invalid_section(line)
  h.assert_true(parser.section_header(line) == nil, ('invalid section parsed: %s'):format(line), scope)
end

local decoded = codec.decode_lines({
  '# ignored',
  '["dynamic.group"]',
  '"Normal" = { fg = "#101010", dynamic = { fg = { version = 1, preset = "pulse", duration = 1500, loop = "pingpong", timeline = [{ at = 0, color = "base" }, { at = 1, color = "#ffffff" }] } } }',
})

h.assert_equal(decoded.groups.Normal, 'dynamic.group', 'section group did not decode', scope)
h.assert_equal(decoded.entries.Normal.dynamic.fg.preset, 'pulse', 'nested dynamic preset did not decode', scope)
h.assert_equal(decoded.entries.Normal.dynamic.fg.timeline[2].color, '#ffffff', 'nested array did not decode', scope)
local nil_decode_ok = pcall(codec.decode_lines, nil)
h.assert_true(not nil_decode_ok, 'codec decode accepted nil lines', scope)
local numeric_line_decode_ok = pcall(codec.decode_lines, { 1 })
h.assert_true(not numeric_line_decode_ok, 'codec decode accepted a non-string line', scope)
local non_sequence_decode_ok = pcall(codec.decode_lines, { [2] = '["late"]' })
h.assert_true(not non_sequence_decode_ok, 'codec decode accepted non-sequence lines', scope)
local invalid_data_decode_ok = pcall(codec.decode_lines, {}, {
  entries = {},
  groups = {},
})
h.assert_true(not invalid_data_decode_ok, 'codec decode accepted incomplete data container', scope)
local numeric_load_ok = pcall(codec.load_file, 1)
h.assert_true(not numeric_load_ok, 'codec load_file accepted a non-string path', scope)
local invalid_data_load_ok = pcall(codec.load_file, 'missing.toml', false)
h.assert_true(not invalid_data_load_ok, 'codec load_file accepted invalid data container', scope)
local missing_file_data = codec.load_file('missing.toml')
h.assert_true(type(missing_file_data.entries) == 'table', 'missing TOML file did not return data entries', scope)
local decoded_into_data = codec.decode_lines({
  '["extra"]',
  '"Extra" = { fg = "#202020" }',
}, codec.empty_data())
h.assert_equal(decoded_into_data.groups.Extra, 'extra', 'codec did not decode into supplied data', scope)

local encoded = codec.encode_section('dynamic.group', {
  Normal = {
    fg = '#101010',
    underdashed = true,
    blend = 12,
    dynamic = {
      fg = {
        version = 1,
        preset = 'pulse',
        duration = 1500,
        loop = 'pingpong',
        timeline = {
          { at = 0, color = 'base' },
          { at = 1, color = '#ffffff' },
        },
      },
    },
  },
})

h.assert_equal(encoded[1], '["dynamic.group"]', 'section header did not encode', scope)
h.assert_equal(
  encoded[2],
  '"Normal" = { fg = "#101010", underdashed = true, blend = 12, dynamic = { fg = { version = 1, preset = "pulse", duration = 1500, loop = "pingpong", timeline = [{ at = 0, color = "base" }, { at = 1, color = "#ffffff" }] } } }',
  'nested dynamic table did not encode deterministically',
  scope
)

local numeric_escape_ok = pcall(util.escape_string, 1)
h.assert_true(not numeric_escape_ok, 'codec string escape accepted a non-string value', scope)
local numeric_section_ok = pcall(codec.encode_section, 1, {})
h.assert_true(not numeric_section_ok, 'codec section accepted a non-string section name', scope)
local empty_section_ok = pcall(codec.encode_section, '', {})
h.assert_true(not empty_section_ok, 'codec section accepted an empty section name', scope)
local numeric_highlight_ok = pcall(codec.encode_section, 'group', {
  [1] = {},
})
h.assert_true(not numeric_highlight_ok, 'codec section accepted a non-string highlight name', scope)
local empty_highlight_ok = pcall(codec.encode_section, 'group', {
  [''] = {},
})
h.assert_true(not empty_highlight_ok, 'codec section accepted an empty highlight name', scope)
local numeric_field_ok = pcall(codec.encode_inline_table, {
  [1] = '#101010',
})
h.assert_true(not numeric_field_ok, 'codec inline table accepted a non-string field name', scope)
local invalid_field_key_ok = pcall(codec.encode_inline_table, {
  ['bad-key'] = '#101010',
})
h.assert_true(not invalid_field_key_ok, 'codec inline table accepted an unsupported field key', scope)
local unsupported_value_ok = pcall(codec.encode_inline_table, {
  fg = function() end,
})
h.assert_true(not unsupported_value_ok, 'codec inline table silently dropped unsupported values', scope)
local non_finite_value_ok = pcall(codec.encode_inline_table, {
  blend = 0 / 0,
})
h.assert_true(not non_finite_value_ok, 'codec inline table accepted non-finite numbers', scope)

local escaped_name, escaped_entry = parser.entry_line([["Escaped" = { label = "quote \" and slash \\" }]])
h.assert_equal(escaped_name, 'Escaped', 'escaped string entry name did not parse', scope)
h.assert_equal(escaped_entry.label, 'quote " and slash \\', 'escaped string value did not parse', scope)
h.assert_equal(
  parser.section_header('["escaped \\" group"]'),
  'escaped " group',
  'escaped section did not parse',
  scope
)

for _, line in ipairs({
  [["escaped \" group"]],
  '[]',
  '[bare]',
  '[""]',
  '["unterminated]',
  '["bad\\n"]',
  '["ok" trailing]',
}) do
  assert_invalid_section(line)
end

for _, line in ipairs({
  [[BareKey = { fg = "#101010" }]],
  [["" = { fg = "#101010" }]],
  [["   " = { fg = "#101010" }]],
  [["BareColor" = { fg = #ffffff }]],
  [["BareDynamic" = { dynamic = { fg = { preset = pulse } } }]],
  [["BadEscape" = { label = "\n" }]],
  [["Duplicate" = { fg = "#101010", fg = "#202020" }]],
  [["InfiniteNumber" = { blend = 1e309 }]],
  [["DanglingTable" = { dynamic = { fg = { preset = "pulse" }}, stray = } }]],
  '"DanglingArray" = { dynamic = { fg = { timeline = [{ at = 0, color = "base" }]] } } }',
}) do
  assert_invalid_entry(line)
end

local strict_decoded = codec.decode_lines({
  '["strict.group"]',
  '"Quoted" = { fg = "#101010" }',
})
h.assert_equal(strict_decoded.groups.Quoted, 'strict.group', 'quoted strict entry did not decode', scope)

for _, case in ipairs({
  {
    lines = {
      '["strict.group"]',
      '"Bare" = { fg = #202020 }',
    },
    message = 'codec decode accepted an invalid entry value',
  },
  {
    lines = {
      '[bare]',
    },
    message = 'codec decode accepted an invalid section',
  },
  {
    lines = {
      '"BeforeSection" = { fg = "#101010" }',
    },
    message = 'codec decode accepted an entry before a section',
  },
  {
    lines = {
      '["first"]',
      '"Duplicate" = { fg = "#101010" }',
      '["second"]',
      '"Duplicate" = { fg = "#202020" }',
    },
    message = 'codec decode accepted a duplicate highlight',
  },
}) do
  local ok = pcall(codec.decode_lines, case.lines)
  h.assert_true(not ok, case.message, scope)
end

local duplicate_data = codec.decode_lines({
  '["first"]',
  '"CrossFileDuplicate" = { fg = "#101010" }',
})
local cross_file_duplicate_ok = pcall(codec.decode_lines, {
  '["second"]',
  '"CrossFileDuplicate" = { fg = "#202020" }',
}, duplicate_data)
h.assert_true(not cross_file_duplicate_ok, 'codec decode accepted a cross-file duplicate highlight', scope)

print('hlcraft persistence codec: OK')
