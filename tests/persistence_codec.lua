local h = require('tests.helpers')
local scope = 'hlcraft persistence codec'

local codec = require('hlcraft.persistence.codec')

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

print('hlcraft persistence codec: OK')
