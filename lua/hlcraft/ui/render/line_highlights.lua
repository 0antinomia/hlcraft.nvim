local line_model = require('hlcraft.ui.render.line_model')
local numbers = require('hlcraft.core.number')
local render_util = require('hlcraft.render.util')
local tables = require('hlcraft.core.tables')
local theme = require('hlcraft.ui.theme')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local span_groups = {
  action = theme.groups.hint_action,
  key = theme.groups.key,
  section = theme.groups.section,
  value = theme.groups.value,
}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('line highlighter requires an instance', 3)
  end
  return instance.state
end

local function instance_namespace(instance)
  if type(instance.ns) ~= 'number' then
    error('line highlighter namespace must be a number', 3)
  end
  if not numbers.is_finite(instance.ns) or math.floor(instance.ns) ~= instance.ns or instance.ns < 0 then
    error('line highlighter namespace must be a non-negative finite integer', 3)
  end
  return instance.ns
end

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
  if type(value) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  if not numbers.is_finite(value) or math.floor(value) ~= value or value < 1 then
    error(('%s must be a positive finite integer'):format(label), 3)
  end
  return value
end

local function non_negative_integer(value, label)
  if type(value) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  if not numbers.is_finite(value) or math.floor(value) ~= value or value < 0 then
    error(('%s must be a non-negative finite integer'):format(label), 3)
  end
  return value
end

local function span_end(value, start_col)
  if type(value) ~= 'number' then
    error('render span end column must be a number', 3)
  end
  if not numbers.is_finite(value) or math.floor(value) ~= value then
    error('render span end column must be a finite integer', 3)
  end
  if value ~= -1 and value < start_col then
    error('render span end column must be -1 or not precede the start column', 3)
  end
  return value
end

local function valid_buffer(buf)
  return type(buf) == 'number' and window.is_valid_buf(buf)
end

local function target_buf(instance, opts)
  local state = instance_state(instance)
  opts = optional_opts(opts)
  if opts.buf ~= nil and not valid_buffer(opts.buf) then
    error('line highlight target buffer must be valid', 3)
  end
  return opts.buf or state.buf
end

local function assert_line(line)
  if type(line) ~= 'string' then
    error('render line must be a string', 3)
  end
  return line
end

local function add_highlight(instance, buf, line_idx, hl, start_col, end_col)
  vim.api.nvim_buf_add_highlight(buf, instance_namespace(instance), hl, line_idx, start_col, end_col)
end

local function assert_span(span)
  if type(span) ~= 'table' then
    error('render span must be a table', 3)
  end
  if type(span.kind) ~= 'string' then
    error('render span kind must be a string', 3)
  end
  span.start_col = non_negative_integer(span.start_col, 'render span start column')
  span.end_col = span_end(span.end_col, span.start_col)
  return span
end

local function assert_spans(spans)
  if type(spans) ~= 'table' then
    error('render spans must be a table', 3)
  end
  if not tables.is_sequence(spans) then
    error('render spans must be a sequence', 3)
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
  line_idx = non_negative_integer(line_idx, 'line highlight index')
  if not valid_buffer(buf) then
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
  line_idx = non_negative_integer(line_idx, 'line highlight index')
  if not valid_buffer(buf) then
    return
  end
  line = assert_line(line)
  apply_spans(instance, buf, line_idx, line_model.label_spans(line))
end

function M.apply_workbench_lines(instance, lines, start_line)
  local state = instance_state(instance)
  local buf = state.buf
  lines = render_util.string_list(lines, 'render lines', 2)
  start_line = start_line == nil and 1 or positive_integer(start_line, 'render start line')
  if not valid_buffer(buf) then
    return
  end

  for index, line in ipairs(lines) do
    if index >= start_line then
      local line_idx = index - 1
      local kind = line_model.line_kind(line)
      if kind == 'rule' then
        add_highlight(instance, buf, line_idx, theme.groups.rule, 0, -1)
      elseif kind == 'title' then
        add_highlight(instance, buf, line_idx, theme.groups.title, 0, -1)
      elseif kind == 'hint' then
        M.apply_hint_line(instance, line_idx, line)
      elseif kind == 'label' then
        M.apply_label_line(instance, line_idx, line)
      end
    end
  end
end

return M
