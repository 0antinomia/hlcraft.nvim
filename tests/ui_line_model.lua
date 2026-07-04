local h = require('tests.helpers')
local scope = 'hlcraft ui line model'

local hints = require('hlcraft.ui.render.hints')
local line_model = require('hlcraft.ui.render.line_model')

local function assert_deep_equal(actual, expected, message)
  h.assert_true(
    vim.deep_equal(actual, expected),
    message .. (' (expected %s, got %s)'):format(vim.inspect(expected), vim.inspect(actual)),
    scope
  )
end

local function compact(spans)
  local result = {}
  for _, span in ipairs(spans) do
    result[#result + 1] = {
      span.kind,
      span.start_col,
      span.end_col,
    }
  end
  return result
end

h.assert_equal(line_model.hint_label('Action  [Enter] open/apply'), 'Action', 'keycap action label not detected', scope)
h.assert_true(line_model.hint_label('Current: #ffffff') == nil, 'value label was treated as hint', scope)
for _, label in ipairs(hints.section_labels) do
  h.assert_equal(
    line_model.hint_label(('%s  [x] action'):format(label)),
    label,
    ('hint section label %s was not detected'):format(label),
    scope
  )
end

h.assert_equal(line_model.line_kind('Detail fields'), 'title', 'detail title not classified', scope)
h.assert_equal(line_model.line_kind('Color editor: FG'), 'title', 'color editor title not classified', scope)
h.assert_equal(line_model.line_kind('────────'), 'rule', 'rule line not classified', scope)
h.assert_equal(line_model.line_kind('Action  [Enter] open/apply'), 'hint', 'hint line not classified', scope)
h.assert_equal(
  line_model.line_kind('        [+/-] time/phase  [e] JSON'),
  'hint',
  'hint continuation not classified',
  scope
)
h.assert_equal(line_model.line_kind('[q / Esc] back/close'), 'hint', 'keycap help item not classified', scope)
h.assert_equal(line_model.line_kind('Current: #ffffff'), 'label', 'label line not classified', scope)
h.assert_true(line_model.line_kind('plain text') == nil, 'plain line was classified', scope)

assert_deep_equal(compact(line_model.hint_spans('Action  [Enter] open/apply  [Tab] input')), {
  { 'section', 0, 6 },
  { 'key', 8, 15 },
  { 'action', 16, 26 },
  { 'key', 28, 33 },
  { 'action', 34, 39 },
}, 'keycap hint spans changed')

assert_deep_equal(compact(line_model.hint_spans('        [+/-] time/phase  [e] JSON')), {
  { 'key', 8, 13 },
  { 'action', 14, 24 },
  { 'key', 26, 29 },
  { 'action', 30, 34 },
}, 'continuation hint spans changed')

assert_deep_equal(compact(line_model.label_spans('Current: #ffffff')), {
  { 'section', 0, 8 },
  { 'value', 9, -1 },
}, 'label spans changed')
h.assert_equal(#line_model.label_spans('plain text'), 0, 'plain text should not have label spans', scope)

print('hlcraft ui line model: OK')
