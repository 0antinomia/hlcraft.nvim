local M = {}

local separator = '  '
local label_width = 8
local default_max_items = 3
local relaxed_max_items = 2

local function pad_label(label)
  local display_width = vim.fn.strdisplaywidth(label)
  if display_width >= label_width then
    return label .. ' '
  end
  return label .. string.rep(' ', label_width - display_width)
end

M.groups = {
  search = {
    { 'Enter', 'open/apply' },
    { 'Tab', 'input' },
    { '?', 'help' },
  },
  detail = {
    { 'Enter', 'edit/toggle' },
    { 's', 'save' },
    { '?', 'help' },
  },
  color_adjust = {
    { 'r/R', 'red' },
    { 'g/G', 'green' },
    { 'b/B', 'blue' },
  },
  color_set = {
    { 'n', 'NONE' },
    { 'i', 'input' },
    { 'd', 'dynamic' },
  },
  color_global = {
    { 's', 'save' },
    { 'q', 'back' },
    { '?', 'help' },
  },
  dynamic_edit = {
    { 'i', 'row' },
    { 'm', 'preset' },
    { '+/-', 'time/phase' },
    { 'e', 'JSON' },
  },
  dynamic_global = {
    { 'd', 'static' },
    { 's', 'save' },
    { 'q', 'back' },
    { '?', 'help' },
  },
  blend_adjust = {
    { '-/+', 'small' },
    { '</>', 'large' },
  },
  blend_set = {
    { 'u', 'unset' },
    { 'i', 'input' },
  },
  blend_global = {
    { 's', 'save' },
    { 'q', 'back' },
    { '?', 'help' },
  },
  group_action = {
    { 'Enter', 'select' },
    { 'i', 'input' },
  },
  group_global = {
    { 's', 'save' },
    { '?', 'help' },
  },
}

local function slice(items, first, last)
  local result = {}
  for index = first, last do
    result[#result + 1] = items[index]
  end
  return result
end

function M.format(items)
  local parts = {}
  for _, item in ipairs(items or {}) do
    local key = item[1] or item.key
    local action = item[2] or item.action
    if key and action then
      parts[#parts + 1] = ('[%s] %s'):format(key, action)
    end
  end
  return table.concat(parts, separator)
end

function M.section_lines(label, group, max_items)
  local items = M.groups[group] or {}
  local chunk_size = math.max(1, max_items or default_max_items)
  local lines = {}

  for first = 1, #items, chunk_size do
    local last = math.min(#items, first + chunk_size - 1)
    local line_label = first == 1 and label or ''
    lines[#lines + 1] = pad_label(line_label) .. M.format(slice(items, first, last))
  end

  if #lines == 0 then
    lines[#lines + 1] = pad_label(label)
  end
  return lines
end

local function section(label, group)
  return M.section_lines(label, group)[1]
end

local function block(spec)
  local lines = {}
  for _, item in ipairs(spec) do
    local section_lines = M.section_lines(item[1], item[2], item.max_items)
    for _, line in ipairs(section_lines) do
      lines[#lines + 1] = line
    end
  end
  return lines
end

function M.search()
  return section('Action', 'search')
end

function M.detail()
  return section('Action', 'detail')
end

function M.color()
  return block({
    { 'Adjust', 'color_adjust', max_items = relaxed_max_items },
    { 'Set', 'color_set', max_items = relaxed_max_items },
    { 'Global', 'color_global', max_items = relaxed_max_items },
  })
end

function M.dynamic()
  return block({
    { 'Edit', 'dynamic_edit', max_items = 2 },
    { 'Global', 'dynamic_global', max_items = 2 },
  })
end

function M.blend()
  return block({
    { 'Adjust', 'blend_adjust', max_items = relaxed_max_items },
    { 'Set', 'blend_set', max_items = relaxed_max_items },
    { 'Global', 'blend_global', max_items = relaxed_max_items },
  })
end

function M.group()
  return block({
    { 'Action', 'group_action' },
    { 'Global', 'group_global' },
  })
end

return M
