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

function M.apply_hint_line(instance, line_idx, line)
  if not window.is_valid_buf(instance.state.buf) then
    return
  end
  line = tostring(line or '')
  if line == '' then
    return
  end

  vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.hint, line_idx, 0, -1)

  local search_start = 1
  local label = M.hint_label(line)
  if label then
    vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.section, line_idx, 0, #label)
    search_start = #label + 1
  end

  local prefix_start, prefix_end = line:find(': ', 1, true)
  if prefix_start and not label then
    vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.section, line_idx, 0, prefix_start)
    search_start = prefix_end + 1
  end

  while search_start <= #line do
    while line:sub(search_start, search_start) == ' ' do
      search_start = search_start + 1
    end
    local separator_start, separator_end = line:find('%s%s+', search_start)
    local pipe_start = line:find('|', search_start, true)
    if pipe_start and (not separator_start or pipe_start < separator_start) then
      separator_start = pipe_start
      separator_end = pipe_start
    end

    local segment_end = separator_start and (separator_start - 1) or #line
    local segment = line:sub(search_start, segment_end)
    local leading_spaces, key = segment:match('^(%s*)(%S+)')
    if key then
      local start_col = search_start + #leading_spaces - 1
      vim.api.nvim_buf_add_highlight(
        instance.state.buf,
        instance.ns,
        theme.groups.key,
        line_idx,
        start_col,
        start_col + #key
      )
    end
    if not separator_start then
      break
    end
    search_start = separator_end + 1
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
