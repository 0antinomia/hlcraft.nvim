local h = require('tests.helpers')
local scope = 'hlcraft persistence codec'

local codec = require('hlcraft.persistence.codec')
local parser = require('hlcraft.persistence.codec.parser')

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
  [["BareColor" = { fg = #ffffff }]],
  [["BareDynamic" = { dynamic = { fg = { preset = pulse } } }]],
  [["BadEscape" = { label = "\n" }]],
  [["Duplicate" = { fg = "#101010", fg = "#202020" }]],
}) do
  assert_invalid_entry(line)
end

local strict_decoded = codec.decode_lines({
  '["strict.group"]',
  '"Quoted" = { fg = "#101010" }',
  '"Bare" = { fg = #202020 }',
})
h.assert_equal(strict_decoded.groups.Quoted, 'strict.group', 'quoted strict entry did not decode', scope)
h.assert_true(strict_decoded.entries.Bare == nil, 'bare string entry should not decode', scope)

print('hlcraft persistence codec: OK')
