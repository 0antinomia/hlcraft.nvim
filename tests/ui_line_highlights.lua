local h = require('tests.helpers')
local scope = 'hlcraft ui line highlights'

local line_highlights = require('hlcraft.ui.render.line_highlights')

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

line_highlights.apply_label_line({
  ns = ns,
  state = {
    buf = help_buf,
  },
}, 0, 'Current: #ffffff')
h.assert_true(
  #vim.api.nvim_buf_get_extmarks(help_buf, ns, 0, -1, { details = true }) > #help_marks,
  'label highlighter did not add spans',
  scope
)

print('hlcraft ui line highlights: OK')
