local h = require('tests.helpers')
local scope = 'hlcraft ui line highlights'

local line_highlights = require('hlcraft.ui.render.line_highlights')

h.assert_equal(line_highlights.hint_label('Action  Enter open/apply'), 'Action', 'action label not detected', scope)
h.assert_equal(line_highlights.hint_label('Adjust: r/R red'), 'Adjust', 'colon hint label not detected', scope)
h.assert_true(line_highlights.hint_label('Current: #ffffff') == nil, 'value label was treated as hint', scope)

h.assert_equal(line_highlights.line_kind('Detail fields'), 'title', 'detail title not classified', scope)
h.assert_equal(line_highlights.line_kind('Color editor: FG'), 'title', 'color editor title not classified', scope)
h.assert_equal(line_highlights.line_kind('────────'), 'rule', 'rule line not classified', scope)
h.assert_equal(line_highlights.line_kind('Action  Enter open/apply'), 'hint', 'hint line not classified', scope)
h.assert_equal(line_highlights.line_kind('Current: #ffffff'), 'label', 'label line not classified', scope)
h.assert_true(line_highlights.line_kind('plain text') == nil, 'plain line was classified', scope)

print('hlcraft ui line highlights: OK')
