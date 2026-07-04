local h = require('tests.helpers')
local scope = 'hlcraft ui json'

local json = require('hlcraft.ui.json')

local formatted = json.format({
  z = 1,
  a = {
    {
      at = 0,
      color = 'base',
    },
  },
  enabled = true,
})

h.assert_equal(
  formatted,
  table.concat({
    '{',
    '  "a": [',
    '    {',
    '      "at": 0,',
    '      "color": "base"',
    '    }',
    '  ],',
    '  "enabled": true,',
    '  "z": 1',
    '}',
  }, '\n'),
  'formatted JSON changed',
  scope
)

h.assert_equal(json.decode_object('{"version":1}').version, 1, 'JSON object did not decode', scope)
h.assert_true(json.decode_object('{}') ~= nil, 'empty JSON object did not decode', scope)
h.assert_true(json.decode_object(123) == nil, 'numeric JSON input decoded as object', scope)
h.assert_true(json.decode_object('[1,2]') == nil, 'JSON array decoded as object', scope)
h.assert_true(json.decode_object('{bad') == nil, 'invalid JSON decoded as object', scope)

print('hlcraft ui json: OK')
