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
h.assert_equal(sequence.name(nil), nil, 'nil field returned a name', scope)

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

h.assert_equal(sequence.next_name(inputs, nil), 'name', 'next without current should use first input', scope)
h.assert_equal(sequence.next_name(inputs, 'name'), 'color', 'next input did not advance', scope)
h.assert_equal(sequence.next_name(inputs, 'blend'), 'name', 'next input did not wrap', scope)
h.assert_equal(sequence.next_name(inputs, 'missing'), 'name', 'next missing current did not use first input', scope)
h.assert_equal(sequence.next_name({}, 'name'), nil, 'next on empty inputs returned a name', scope)

h.assert_equal(sequence.prev_name(inputs, nil), 'blend', 'prev without current should use last input', scope)
h.assert_equal(sequence.prev_name(inputs, 'blend'), 'fg', 'prev input did not move backward', scope)
h.assert_equal(sequence.prev_name(inputs, 'name'), 'blend', 'prev input did not wrap', scope)
h.assert_equal(sequence.prev_name(inputs, 'missing'), 'blend', 'prev missing current did not use last input', scope)
h.assert_equal(sequence.prev_name({}, 'name'), nil, 'prev on empty inputs returned a name', scope)

print('hlcraft ui input sequence: OK')
