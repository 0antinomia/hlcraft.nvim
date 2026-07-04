local h = require('tests.helpers')
local scope = 'hlcraft notify'

local notify = require('hlcraft.notify')

local calls = {}
h.with_notify_stub(function()
  notify.error('bad input')
  notify.warn('soft failure')
  notify.error(nil)
end, function(message, level)
  calls[#calls + 1] = { message = message, level = level }
end)

h.assert_equal(#calls, 2, 'nil notification should be skipped', scope)
h.assert_equal(calls[1].message, 'hlcraft: bad input', 'error notification message changed', scope)
h.assert_equal(calls[1].level, vim.log.levels.ERROR, 'error notification level changed', scope)
h.assert_equal(calls[2].message, 'hlcraft: soft failure', 'warn notification message changed', scope)
h.assert_equal(calls[2].level, vim.log.levels.WARN, 'warn notification level changed', scope)

print('hlcraft notify: OK')
