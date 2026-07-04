local h = require('tests.helpers')
local scope = 'hlcraft ui style editor'

local style = require('hlcraft.ui.editor.style')

h.assert_equal(style.next_boolean(nil), true, 'nil did not cycle to true', scope)
h.assert_equal(style.next_boolean(true), false, 'true did not cycle to false', scope)
h.assert_equal(style.next_boolean(false), nil, 'false did not cycle to nil', scope)
h.assert_equal(style.next_boolean('ignored'), true, 'non-boolean did not cycle to true', scope)

print('hlcraft ui style editor: OK')
