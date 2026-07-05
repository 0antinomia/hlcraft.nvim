local numbers = require('hlcraft.core.number')

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

local function assert_table(value, message)
  if type(value) ~= 'table' then
    error(message, 3)
  end
  return value
end

local function assert_positive_integer(value, message)
  if type(value) ~= 'number' or not numbers.is_finite(value) or math.floor(value) ~= value or value < 1 then
    error(message, 3)
  end
  return value
end

local function non_empty_string(value, label)
  if type(value) ~= 'string' or value == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return value
end

local function section_options(options)
  options = options == nil and {} or assert_table(options, 'hint section options must be a table')
  local max_items = default_max_items
  if options.max_items ~= nil then
    max_items = assert_positive_integer(options.max_items, 'hint max_items must be a positive integer')
  end
  local width = nil
  if options.width ~= nil then
    width = assert_positive_integer(options.width, 'hint width must be a positive integer')
  end
  return max_items, width
end

local function format_item(item)
  assert_table(item, 'hint item must be a table')
  local key = item[1]
  local action = item[2]
  if type(key) ~= 'string' or key == '' then
    error('hint item requires a key', 3)
  end
  if type(action) ~= 'string' or action == '' then
    error('hint item requires an action', 3)
  end
  return ('[%s] %s'):format(key, action)
end

local function format_range(items, first, last)
  local parts = {}
  items = assert_table(items, 'hint items must be a table')
  first = first or 1
  last = last or #items

  for index = first, last do
    parts[#parts + 1] = format_item(items[index])
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
  label = non_empty_string(label, 'hint section label')
  group = non_empty_string(group, 'hint group')
  local max_items, width = section_options(options)
  local items = M.groups[group]
  if items == nil then
    error(('unknown hint group: %s'):format(tostring(group)), 2)
  end
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
