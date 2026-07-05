local h = require('tests.helpers')
local scope = 'hlcraft test helpers'

h.assert_fails(function()
  error('expected failure', 0)
end, 'assert_fails rejected a failing callback', scope)

local passing_callback_ok = pcall(function()
  h.assert_fails(function() end, 'passing callback was accepted', scope)
end)
h.assert_true(not passing_callback_ok, 'assert_fails accepted a passing callback', scope)

local invalid_callback_ok = pcall(h.assert_fails, nil, 'invalid callback was accepted', scope)
h.assert_true(not invalid_callback_ok, 'assert_fails accepted a missing callback', scope)

print('hlcraft test helpers: OK')
