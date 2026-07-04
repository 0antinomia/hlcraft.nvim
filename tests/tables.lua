local h = require('tests.helpers')
local scope = 'hlcraft core tables'

local tables = require('hlcraft.core.tables')

h.assert_true(tables.is_sequence({}), 'empty table should be a sequence', scope)
h.assert_true(tables.is_sequence({ 'a', 'b' }), 'array table should be a sequence', scope)
h.assert_true(not tables.is_sequence({ [1] = 'a', [3] = 'b' }), 'sparse table was accepted', scope)
h.assert_true(not tables.is_sequence({ a = 1 }), 'named table was accepted', scope)
h.assert_true(not tables.is_sequence({ [0] = 'zero' }), 'zero index table was accepted', scope)
h.assert_true(not tables.is_sequence({ [1.5] = 'half' }), 'fractional index table was accepted', scope)
h.assert_true(not tables.is_sequence({ [1] = 'a', extra = 'b' }), 'mixed-key table was accepted', scope)
h.assert_true(not tables.is_sequence('not a table'), 'non-table value was accepted', scope)

print('hlcraft core tables: OK')
