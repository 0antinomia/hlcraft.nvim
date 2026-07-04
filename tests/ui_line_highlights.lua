local h = require('tests.helpers')
local scope = 'hlcraft ui line highlights'

local line_highlights = require('hlcraft.ui.render.line_highlights')

h.assert_equal(line_highlights.hint_label('Action  Enter open/apply'), 'Action', 'action label not detected', scope)
h.assert_equal(
  line_highlights.hint_label('Action  [Enter] open/apply'),
  'Action',
  'keycap action label not detected',
  scope
)
h.assert_equal(line_highlights.hint_label('Adjust: r/R red'), 'Adjust', 'colon hint label not detected', scope)
h.assert_true(line_highlights.hint_label('Current: #ffffff') == nil, 'value label was treated as hint', scope)

h.assert_equal(line_highlights.line_kind('Detail fields'), 'title', 'detail title not classified', scope)
h.assert_equal(line_highlights.line_kind('Color editor: FG'), 'title', 'color editor title not classified', scope)
h.assert_equal(line_highlights.line_kind('────────'), 'rule', 'rule line not classified', scope)
h.assert_equal(line_highlights.line_kind('Action  Enter open/apply'), 'hint', 'hint line not classified', scope)
h.assert_equal(
  line_highlights.line_kind('        [+/-] time/phase  [e] JSON'),
  'hint',
  'hint continuation not classified',
  scope
)
h.assert_equal(line_highlights.line_kind('[q / Esc] back or close'), 'hint', 'keycap help item not classified', scope)
h.assert_equal(line_highlights.line_kind('Current: #ffffff'), 'label', 'label line not classified', scope)
h.assert_true(line_highlights.line_kind('plain text') == nil, 'plain line was classified', scope)

local ns = vim.api.nvim_create_namespace('hlcraft-ui-line-highlights-test')
local workspace_buf = vim.api.nvim_create_buf(false, true)
local help_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(workspace_buf, 0, -1, false, { '[q] close' })
vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, { '[q] close' })

line_highlights.apply_hint_line({
  ns = ns,
  state = {
    buf = workspace_buf,
  },
}, 0, '[q] close', { buf = help_buf })

local workspace_marks = vim.api.nvim_buf_get_extmarks(workspace_buf, ns, 0, -1, { details = true })
local help_marks = vim.api.nvim_buf_get_extmarks(help_buf, ns, 0, -1, { details = true })
h.assert_equal(#workspace_marks, 0, 'hint highlighter wrote to the workspace buffer', scope)
h.assert_true(#help_marks > 0, 'hint highlighter did not write to the requested buffer', scope)

print('hlcraft ui line highlights: OK')
