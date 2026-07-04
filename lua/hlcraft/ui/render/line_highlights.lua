local line_model = require('hlcraft.ui.render.line_model')
local theme = require('hlcraft.ui.theme')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local span_groups = {
  action = theme.groups.hint_action,
  key = theme.groups.key,
  section = theme.groups.section,
  value = theme.groups.value,
}

local function target_buf(instance, opts)
  return opts and opts.buf or instance.state.buf
end

local function add_highlight(instance, buf, line_idx, hl, start_col, end_col)
  vim.api.nvim_buf_add_highlight(buf, instance.ns, hl, line_idx, start_col, end_col)
end

local function apply_spans(instance, buf, line_idx, spans)
  for _, span in ipairs(spans or {}) do
    local group = span_groups[span.kind]
    if group then
      add_highlight(instance, buf, line_idx, group, span.start_col, span.end_col)
    end
  end
end

function M.apply_hint_line(instance, line_idx, line, opts)
  local buf = target_buf(instance, opts)
  if not window.is_valid_buf(buf) then
    return
  end
  line = tostring(line or '')
  if line == '' then
    return
  end

  add_highlight(instance, buf, line_idx, theme.groups.hint, 0, -1)
  apply_spans(instance, buf, line_idx, line_model.hint_spans(line))
end

function M.apply_label_line(instance, line_idx, line, opts)
  local buf = target_buf(instance, opts)
  if not window.is_valid_buf(buf) then
    return
  end
  apply_spans(instance, buf, line_idx, line_model.label_spans(line))
end

function M.apply_workbench_lines(instance, lines, start_line)
  start_line = start_line or 1
  for index, line in ipairs(lines or {}) do
    if index >= start_line then
      local line_idx = index - 1
      local kind = line_model.line_kind(line)
      if kind == 'rule' then
        vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.rule, line_idx, 0, -1)
      elseif kind == 'title' then
        vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.title, line_idx, 0, -1)
      elseif kind == 'hint' then
        M.apply_hint_line(instance, line_idx, line)
      elseif kind == 'label' then
        M.apply_label_line(instance, line_idx, line)
      end
    end
  end
end

return M
