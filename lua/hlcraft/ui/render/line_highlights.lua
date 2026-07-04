local theme = require('hlcraft.ui.theme')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local hint_labels = {
  Action = true,
  Adjust = true,
  Edit = true,
  Global = true,
  Set = true,
}

function M.hint_label(line)
  local label = tostring(line or ''):match('^(%S+)%s%s+')
  if label and hint_labels[label] then
    return label
  end

  local colon_label = tostring(line or ''):match('^(%S+):%s+')
  if colon_label and hint_labels[colon_label] then
    return colon_label
  end

  return nil
end

local function is_hint_line(line)
  return M.hint_label(line) ~= nil or tostring(line or ''):find(' | ', 1, true) ~= nil
end

local function is_rule_line(line)
  return tostring(line or ''):match('^[─%-]+$') ~= nil
end

local function is_title_line(line)
  line = tostring(line or '')
  return line == 'Detail fields'
    or line == 'Blend editor'
    or line:find('^Color editor:', 1) ~= nil
    or line:find('^Group editor:', 1) ~= nil
end

function M.line_kind(line)
  if is_rule_line(line) then
    return 'rule'
  end
  if is_title_line(line) then
    return 'title'
  end
  if is_hint_line(line) then
    return 'hint'
  end
  if tostring(line or ''):find(':', 1, true) then
    return 'label'
  end
  return nil
end

local function add_highlight(instance, line_idx, hl, start_col, end_col)
  vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, hl, line_idx, start_col, end_col)
end

local function trim_bounds(line, first, last)
  while first <= last and line:sub(first, first) == ' ' do
    first = first + 1
  end
  while last >= first and line:sub(last, last) == ' ' do
    last = last - 1
  end
  if first > last then
    return nil, nil
  end
  return first, last
end

local function apply_hint_segment(instance, line_idx, line, first, last)
  first, last = trim_bounds(line, first, last)
  if not first then
    return
  end

  local segment = line:sub(first, last)
  local key_start, key_end = segment:find('%S+')
  if not key_start then
    return
  end

  local key_col_start = first + key_start - 2
  local key_col_end = first + key_end - 1
  add_highlight(instance, line_idx, theme.groups.key, key_col_start, key_col_end)

  local action_start = first + key_end
  while action_start <= last and line:sub(action_start, action_start) == ' ' do
    action_start = action_start + 1
  end
  if action_start <= last then
    add_highlight(instance, line_idx, theme.groups.hint_action, action_start - 1, last)
  end
end

function M.apply_hint_line(instance, line_idx, line)
  if not window.is_valid_buf(instance.state.buf) then
    return
  end
  line = tostring(line or '')
  if line == '' then
    return
  end

  add_highlight(instance, line_idx, theme.groups.hint, 0, -1)

  local search_start = 1
  local label = M.hint_label(line)
  if label then
    add_highlight(instance, line_idx, theme.groups.section, 0, #label)
    search_start = #label + 1
  end

  local prefix_start, prefix_end = line:find(': ', 1, true)
  if prefix_start and not label then
    add_highlight(instance, line_idx, theme.groups.section, 0, prefix_start)
    search_start = prefix_end + 1
  end

  while search_start <= #line do
    local pipe_start = line:find('|', search_start, true)
    local segment_end = pipe_start and pipe_start - 1 or #line
    apply_hint_segment(instance, line_idx, line, search_start, segment_end)
    if not pipe_start then
      break
    end
    add_highlight(instance, line_idx, theme.groups.hint_separator, pipe_start - 1, pipe_start)
    search_start = pipe_start + 1
  end
end

function M.apply_label_line(instance, line_idx, line)
  if not window.is_valid_buf(instance.state.buf) then
    return
  end
  line = tostring(line or '')
  local colon = line:find(':', 1, true)
  if not colon then
    return
  end
  vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.section, line_idx, 0, colon)
  if colon < #line then
    vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.value, line_idx, colon + 1, -1)
  end
end

function M.apply_workbench_lines(instance, lines, start_line)
  start_line = start_line or 1
  for index, line in ipairs(lines or {}) do
    if index >= start_line then
      local line_idx = index - 1
      local kind = M.line_kind(line)
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
