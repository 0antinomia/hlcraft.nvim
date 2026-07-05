local h = require('tests.helpers')
local scope = 'hlcraft core tables'

local tables = require('hlcraft.core.tables')

h.assert_true(tables.is_sequence({}), 'empty table should be a sequence', scope)
h.assert_true(tables.is_sequence({ 'a', 'b' }), 'array table should be a sequence', scope)
h.assert_true(not tables.is_sequence({ [1] = 'a', [3] = 'b' }), 'sparse table was accepted', scope)
h.assert_true(not tables.is_sequence({ [1] = 'a', [2] = 'b', [4] = 'd' }), 'trailing gap table was accepted', scope)
h.assert_true(not tables.is_sequence({ [2] = 'b' }), 'non-one-based table was accepted', scope)
h.assert_true(not tables.is_sequence({ a = 1 }), 'named table was accepted', scope)
h.assert_true(not tables.is_sequence({ [0] = 'zero' }), 'zero index table was accepted', scope)
h.assert_true(not tables.is_sequence({ [1.5] = 'half' }), 'fractional index table was accepted', scope)
h.assert_true(not tables.is_sequence({ [1] = 'a', extra = 'b' }), 'mixed-key table was accepted', scope)
h.assert_true(not tables.is_sequence('not a table'), 'non-table value was accepted', scope)
local sample_sequence = { 'a', 'b' }
h.assert_true(
  tables.assert_sequence(sample_sequence, 'sample') == sample_sequence,
  'sequence assertion changed value',
  scope
)
local nil_sequence_ok = pcall(tables.assert_sequence, nil, 'sample')
h.assert_true(not nil_sequence_ok, 'sequence assertion accepted nil', scope)
local sparse_sequence_ok = pcall(tables.assert_sequence, { [2] = 'late' }, 'sample')
h.assert_true(not sparse_sequence_ok, 'sequence assertion accepted sparse table', scope)
local invalid_sequence_label_ok = pcall(tables.assert_sequence, {}, '')
h.assert_true(not invalid_sequence_label_ok, 'sequence assertion accepted empty label', scope)

local sorted = tables.sorted_keys({ b = true, a = true, c = true })
h.assert_equal(table.concat(sorted, ','), 'a,b,c', 'keys were not sorted', scope)
local nil_sorted_keys_ok = pcall(tables.sorted_keys, nil)
h.assert_true(not nil_sorted_keys_ok, 'sorted_keys accepted nil table', scope)
local custom_sorted = tables.sorted_keys({ short = true, longest = true }, function(left, right)
  return #left > #right
end)
h.assert_equal(custom_sorted[1], 'longest', 'custom key comparator was ignored', scope)

h.assert_true(tables.has_only_keys({ fg = true }, { fg = true, bg = true }), 'allowed key was rejected', scope)
h.assert_true(not tables.has_only_keys({ sp = true }, { fg = true, bg = true }), 'unknown key was accepted', scope)
h.assert_true(not tables.has_only_keys(nil, { fg = true }), 'nil value key check was accepted', scope)
h.assert_true(not tables.has_only_keys({ fg = true }, nil), 'nil allowed key set was accepted', scope)

print('hlcraft core tables: OK')
