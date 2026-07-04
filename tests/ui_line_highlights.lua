local h = require('tests.helpers')
local scope = 'hlcraft ui line highlights'

local line_highlights = require('hlcraft.ui.render.line_highlights')

local ns = vim.api.nvim_create_namespace('hlcraft-ui-line-highlights-test')
h.with_temp_bufs(2, function(workspace_buf, help_buf)
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

  local numeric_hint_ok = pcall(line_highlights.apply_hint_line, {
    ns = ns,
    state = {
      buf = help_buf,
    },
  }, 0, 1)
  h.assert_true(not numeric_hint_ok, 'hint highlighter accepted a non-string line', scope)

  local numeric_label_ok = pcall(line_highlights.apply_label_line, {
    ns = ns,
    state = {
      buf = help_buf,
    },
  }, 0, 1)
  h.assert_true(not numeric_label_ok, 'label highlighter accepted a non-string line', scope)

  local invalid_lines_ok = pcall(line_highlights.apply_workbench_lines, {
    ns = ns,
    state = {
      buf = help_buf,
    },
  }, nil)
  h.assert_true(not invalid_lines_ok, 'workbench highlighter accepted non-table lines', scope)
end)

local line_highlights_module = 'hlcraft.ui.render.line_highlights'
local line_model_module = 'hlcraft.ui.render.line_model'
local original_line_highlights = package.loaded[line_highlights_module]
local original_line_model = package.loaded[line_model_module]

h.with_temp_buf(function(buf)
  local ok, err = xpcall(function()
    package.loaded[line_highlights_module] = nil
    package.loaded[line_model_module] = {
      hint_spans = function()
        return nil
      end,
      label_spans = function()
        return {}
      end,
    }
    local strict_line_highlights = require(line_highlights_module)
    local nil_spans_ok = pcall(strict_line_highlights.apply_hint_line, {
      ns = ns,
      state = {
        buf = buf,
      },
    }, 0, '[q] close')
    h.assert_true(not nil_spans_ok, 'line highlighter accepted nil spans', scope)
  end, debug.traceback)

  package.loaded[line_highlights_module] = original_line_highlights
  package.loaded[line_model_module] = original_line_model

  if not ok then
    error(err, 0)
  end
end)

print('hlcraft ui line highlights: OK')
