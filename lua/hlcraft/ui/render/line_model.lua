local M = {}

local hint_labels = require('hlcraft.ui.render.hints').section_label_set

local function assert_line(line)
  if type(line) ~= 'string' then
    error('render line must be a string', 3)
  end
  return line
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

local function span(spans, kind, start_col, end_col)
  spans[#spans + 1] = {
    kind = kind,
    start_col = start_col,
    end_col = end_col,
  }
end

local function keycap_spans(line, first, last, spans)
  local search_start = first

  while search_start <= last do
    local key_start, key_end = line:find('%b[]', search_start)
    if not key_start or key_start > last then
      break
    end

    span(spans, 'key', key_start - 1, key_end)

    local action_start = key_end + 1
    while action_start <= last and line:sub(action_start, action_start) == ' ' do
      action_start = action_start + 1
    end

    local next_key_start = line:find('%b[]', action_start)
    local action_end = next_key_start and math.min(last, next_key_start - 1) or last
    local trimmed_start, trimmed_end = trim_bounds(line, action_start, action_end)
    if trimmed_start then
      span(spans, 'action', trimmed_start - 1, trimmed_end)
    end

    search_start = next_key_start or (last + 1)
  end
end

local function hint_segment_spans(line, first, last, spans)
  first, last = trim_bounds(line, first, last)
  if not first then
    return
  end

  keycap_spans(line, first, last, spans)
end

local function hint_prefix(line)
  local label = line:match('^(%S+)%s%s+')
  if label and hint_labels[label] then
    return label, #label, #label + 1
  end

  return nil, nil, 1
end

function M.hint_label(line)
  return hint_prefix(assert_line(line))
end

local function is_hint_line(line)
  return M.hint_label(line) ~= nil or line:find('^%s*%b[]%s+') ~= nil
end

local function is_rule_line(line)
  return line:match('^[─%-]+$') ~= nil
end

local function is_title_line(line)
  return line == 'Detail fields'
    or line == 'Blend editor'
    or line:find('^Color editor:', 1) ~= nil
    or line:find('^Group editor:', 1) ~= nil
end

function M.line_kind(line)
  line = assert_line(line)
  if is_rule_line(line) then
    return 'rule'
  end
  if is_title_line(line) then
    return 'title'
  end
  if is_hint_line(line) then
    return 'hint'
  end
  if line:find(':', 1, true) then
    return 'label'
  end
  return nil
end

function M.hint_spans(line)
  line = assert_line(line)
  local spans = {}
  if line == '' then
    return spans
  end

  local label, section_end, search_start = hint_prefix(line)
  if label then
    span(spans, 'section', 0, section_end)
  end

  hint_segment_spans(line, search_start, #line, spans)

  return spans
end

function M.label_spans(line)
  line = assert_line(line)
  local colon = line:find(':', 1, true)
  if not colon then
    return {}
  end

  local spans = {
    {
      kind = 'section',
      start_col = 0,
      end_col = colon,
    },
  }
  if colon < #line then
    span(spans, 'value', colon + 1, -1)
  end
  return spans
end

return M
