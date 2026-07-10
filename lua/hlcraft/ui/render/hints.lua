local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')

local M = {}

local separator = '  '
local label_width = 8
local default_max_items = 3
local relaxed_max_items = 2

local function key_set(keys)
  keys = tables.assert_sequence(keys, 'key set values', 3)
  local result = {}
  for _, key in ipairs(keys) do
    result[key] = true
  end
  return result
end

local section_labels = {
  'Action',
  'Adjust',
  'Edit',
  'Global',
  'Set',
}
M.section_label_set = key_set(section_labels)

local function pad_label(label)
  local display_width = vim.fn.strdisplaywidth(label)
  if display_width >= label_width then
    return label .. ' '
  end
  return label .. string.rep(' ', label_width - display_width)
end

local groups = {
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
  if not numbers.is_integer(value, 1) then
    error(message, 3)
  end
  return value
end

local function non_empty_string(value, label)
  if type(value) ~= 'string' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  value = vim.trim(value)
  if value == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return value
end

local function section_options(options)
  options = options == nil and {} or assert_table(options, 'hint section options must be a table')
  for key in pairs(options) do
    if key ~= 'max_items' and key ~= 'width' then
      error(('unknown hint section option: %s'):format(tostring(key)), 3)
    end
  end
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
  local key = non_empty_string(item[1], 'hint item key')
  local action = non_empty_string(item[2], 'hint item action')
  return ('[%s] %s'):format(key, action)
end

local function format_range(items, first, last)
  local parts = {}
  items = tables.assert_sequence(items, 'hint items', 3)
  first = first or 1
  last = last or #items

  for index = first, last do
    parts[#parts + 1] = format_item(items[index])
  end
  return table.concat(parts, separator)
end

local function line_display_width(label, items, first, last)
  return vim.fn.strdisplaywidth(pad_label(label) .. format_range(items, first, last))
end

function M.section_lines(label, group, options)
  label = non_empty_string(label, 'hint section label')
  group = non_empty_string(group, 'hint group')
  local max_items, width = section_options(options)
  local items = groups[group]
  if items == nil then
    error(('unknown hint group: %s'):format(tostring(group)), 2)
  end
  items = tables.assert_sequence(items, 'hint items', 3)
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

local function single_section(label, group, width)
  return M.section_lines(label, group, { width = width })
end

local function block(spec, width)
  spec = tables.assert_sequence(spec, 'hint block spec', 3)
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

function M.search(width)
  return single_section('Action', 'search', width)
end

function M.detail(width)
  return single_section('Action', 'detail', width)
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
