local h = require('tests.helpers')
local scope = 'hlcraft ui input sequence'

local sequence = require('hlcraft.ui.input.sequence')

local inputs = {
  { name = 'name', kind = 'name' },
  { name = 'color', kind = 'color' },
  { key = 'fg', name = 'field', kind = 'detail' },
  { key = 'blend', name = 'field', kind = 'detail' },
}

h.assert_equal(sequence.name(inputs[1]), 'name', 'field name did not use name', scope)
h.assert_equal(sequence.name(inputs[3]), 'fg', 'field name did not prefer key', scope)
local nil_field_ok = pcall(sequence.name, nil)
h.assert_true(not nil_field_ok, 'input sequence accepted nil field', scope)
local unnamed_field_ok = pcall(sequence.name, { kind = 'name' })
h.assert_true(not unnamed_field_ok, 'input sequence accepted unnamed field', scope)
local false_key_ok = pcall(sequence.name, { key = false, name = 'field', kind = 'detail' })
h.assert_true(not false_key_ok, 'input sequence ignored invalid false key', scope)

h.assert_equal(sequence.first_name(inputs), 'name', 'first input name changed', scope)
h.assert_equal(
  sequence.first_name(inputs, function(field)
    return field.kind == 'detail'
  end),
  'fg',
  'filtered first input name changed',
  scope
)
h.assert_equal(
  sequence.first_name(inputs, function(field)
    return field.kind == 'missing'
  end),
  nil,
  'missing filtered input returned a name',
  scope
)
local nil_inputs_ok = pcall(sequence.first_name, nil)
h.assert_true(not nil_inputs_ok, 'input sequence accepted nil inputs', scope)
local sparse_inputs_ok = pcall(sequence.first_name, { [2] = { name = 'late' } })
h.assert_true(not sparse_inputs_ok, 'input sequence accepted sparse inputs', scope)
local keyed_inputs_ok = pcall(sequence.first_name, { extra = { name = 'extra' } })
h.assert_true(not keyed_inputs_ok, 'input sequence accepted keyed inputs', scope)
local bad_predicate_ok = pcall(sequence.first_name, inputs, true)
h.assert_true(not bad_predicate_ok, 'input sequence accepted non-function predicate', scope)

h.assert_equal(sequence.next_name(inputs, nil), 'name', 'next without current should use first input', scope)
h.assert_equal(sequence.next_name(inputs, 'name'), 'color', 'next input did not advance', scope)
h.assert_equal(sequence.next_name(inputs, 'blend'), 'name', 'next input did not wrap', scope)
h.assert_equal(sequence.next_name(inputs, 'missing'), 'name', 'next missing current did not use first input', scope)
h.assert_equal(sequence.next_name({}, 'name'), nil, 'next on empty inputs returned a name', scope)
local bad_next_current_ok = pcall(sequence.next_name, inputs, 1)
h.assert_true(not bad_next_current_ok, 'input sequence accepted non-string next current name', scope)
local empty_next_current_ok = pcall(sequence.next_name, inputs, '')
h.assert_true(not empty_next_current_ok, 'input sequence accepted empty next current name', scope)

h.assert_equal(sequence.prev_name(inputs, nil), 'blend', 'prev without current should use last input', scope)
h.assert_equal(sequence.prev_name(inputs, 'blend'), 'fg', 'prev input did not move backward', scope)
h.assert_equal(sequence.prev_name(inputs, 'name'), 'blend', 'prev input did not wrap', scope)
h.assert_equal(sequence.prev_name(inputs, 'missing'), 'blend', 'prev missing current did not use last input', scope)
h.assert_equal(sequence.prev_name({}, 'name'), nil, 'prev on empty inputs returned a name', scope)
local bad_prev_inputs_ok = pcall(sequence.prev_name, nil, 'name')
h.assert_true(not bad_prev_inputs_ok, 'input sequence accepted nil prev inputs', scope)
local empty_prev_current_ok = pcall(sequence.prev_name, inputs, '')
h.assert_true(not empty_prev_current_ok, 'input sequence accepted empty prev current name', scope)

print('hlcraft ui input sequence: OK')
