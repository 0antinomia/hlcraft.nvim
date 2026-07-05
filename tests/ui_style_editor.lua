local h = require('tests.helpers')
local scope = 'hlcraft ui style editor'

local style = require('hlcraft.ui.editor.style')

h.assert_equal(style.next_boolean(nil), true, 'nil did not cycle to true', scope)
h.assert_equal(style.next_boolean(true), false, 'true did not cycle to false', scope)
h.assert_equal(style.next_boolean(false), nil, 'false did not cycle to nil', scope)
local invalid_value, invalid_err = style.next_boolean('ignored')
h.assert_true(invalid_value == nil, 'non-boolean style returned a next value', scope)
h.assert_equal(invalid_err, 'Style value must be boolean or nil', 'non-boolean style error changed', scope)
local invalid_result_ok = pcall(style.toggle, {}, {}, 'bold')
h.assert_true(not invalid_result_ok, 'style editor accepted a nameless result', scope)
local invalid_field_ok = pcall(style.toggle, {}, { name = 'Normal' }, false)
h.assert_true(not invalid_field_ok, 'style editor accepted an invalid field', scope)

print('hlcraft ui style editor: OK')
