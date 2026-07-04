local M = {}

local separator = '  '
local label_width = 8
local default_max_items = 3
local relaxed_max_items = 2

local function key_set(keys)
  local result = {}
  for _, key in ipairs(keys) do
    result[key] = true
  end
  return result
end

M.section_labels = {
  'Action',
  'Adjust',
  'Edit',
  'Global',
  'Set',
}
M.section_label_set = key_set(M.section_labels)

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

local function normalize_options(options)
  if type(options) == 'table' then
    return options
  end
  return { max_items = options }
end

local function format_range(items, first, last)
  local parts = {}
  items = items or {}
  first = first or 1
  last = last or #items

  for index = first, last do
    local item = items[index] or {}
    local key = item[1] or item.key
    local action = item[2] or item.action
    if key and action then
      parts[#parts + 1] = ('[%s] %s'):format(key, action)
    end
  end
  return table.concat(parts, separator)
end

function M.format(items)
  return format_range(items)
end

local function line_display_width(label, items, first, last)
  return vim.fn.strdisplaywidth(pad_label(label) .. format_range(items, first, last))
end

function M.section_lines(label, group, options)
  options = normalize_options(options)
  local items = M.groups[group] or {}
  local max_items = math.max(1, options.max_items or default_max_items)
  local width = options.width
  local lines = {}

  local first = 1
  while first <= #items do
    local chunk_size = math.min(max_items, #items - first + 1)
    local line_label = first == 1 and label or ''

    while width and chunk_size > 1 and line_display_width(line_label, items, first, first + chunk_size - 1) > width do
      chunk_size = chunk_size - 1
    end

    local last = math.min(#items, first + chunk_size - 1)
    lines[#lines + 1] = pad_label(line_label) .. format_range(items, first, last)
    first = last + 1
  end

  if #lines == 0 then
    lines[#lines + 1] = pad_label(label)
  end
  return lines
end

local function section(label, group)
  return M.section_lines(label, group)[1]
end

local function block(spec, width)
  local lines = {}
  for index, item in ipairs(spec) do
    if index > 1 then
      lines[#lines + 1] = ''
    end
    local section_lines = M.section_lines(item[1], item[2], {
      max_items = item.max_items,
      width = width,
    })
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

function M.color(width)
  return block({
    { 'Adjust', 'color_adjust', max_items = relaxed_max_items },
    { 'Set', 'color_set', max_items = relaxed_max_items },
    { 'Global', 'color_global', max_items = relaxed_max_items },
  }, width)
end

function M.dynamic(width)
  return block({
    { 'Edit', 'dynamic_edit', max_items = 2 },
    { 'Global', 'dynamic_global', max_items = 2 },
  }, width)
end

function M.blend(width)
  return block({
    { 'Adjust', 'blend_adjust', max_items = relaxed_max_items },
    { 'Set', 'blend_set', max_items = relaxed_max_items },
    { 'Global', 'blend_global', max_items = relaxed_max_items },
  }, width)
end

function M.group(width)
  return block({
    { 'Action', 'group_action' },
    { 'Global', 'group_global' },
  }, width)
end

return M
