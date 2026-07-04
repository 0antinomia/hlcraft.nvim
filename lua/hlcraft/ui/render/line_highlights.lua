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

local function optional_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error('line highlight options must be a table', 3)
  end
  return opts
end

local function positive_integer(value, label)
  if type(value) ~= 'number' or math.floor(value) ~= value or value < 1 then
    error(('%s must be a positive integer'):format(label), 3)
  end
  return value
end

local function target_buf(instance, opts)
  opts = optional_opts(opts)
  if opts.buf ~= nil and not window.is_valid_buf(opts.buf) then
    error('line highlight target buffer must be valid', 3)
  end
  return opts.buf or instance.state.buf
end

local function assert_line(line)
  if type(line) ~= 'string' then
    error('render line must be a string', 3)
  end
  return line
end

local function add_highlight(instance, buf, line_idx, hl, start_col, end_col)
  vim.api.nvim_buf_add_highlight(buf, instance.ns, hl, line_idx, start_col, end_col)
end

local function assert_span(span)
  if type(span) ~= 'table' then
    error('render span must be a table', 3)
  end
  if type(span.kind) ~= 'string' then
    error('render span kind must be a string', 3)
  end
  if type(span.start_col) ~= 'number' or type(span.end_col) ~= 'number' then
    error('render span range must be numeric', 3)
  end
  return span
end

local function assert_spans(spans)
  if type(spans) ~= 'table' then
    error('render spans must be a table', 3)
  end
  return spans
end

local function apply_spans(instance, buf, line_idx, spans)
  for _, span in ipairs(assert_spans(spans)) do
    span = assert_span(span)
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
  line = assert_line(line)
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
  line = assert_line(line)
  apply_spans(instance, buf, line_idx, line_model.label_spans(line))
end

function M.apply_workbench_lines(instance, lines, start_line)
  if type(lines) ~= 'table' then
    error('render lines must be a table', 2)
  end

  start_line = start_line == nil and 1 or positive_integer(start_line, 'render start line')
  for index, line in ipairs(lines) do
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
