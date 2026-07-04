local M = {}

local separator = '   '
local label_width = 8

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

function M.format(items)
  local parts = {}
  for _, item in ipairs(items or {}) do
    local key = item[1] or item.key
    local action = item[2] or item.action
    if key and action then
      parts[#parts + 1] = ('%s %s'):format(key, action)
    end
  end
  return table.concat(parts, separator)
end

local function section(label, group)
  return pad_label(label) .. M.format(groups[group])
end

local function block(spec)
  local lines = {}
  for _, item in ipairs(spec) do
    lines[#lines + 1] = section(item[1], item[2])
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
    { 'Adjust', 'color_adjust' },
    { 'Set', 'color_set' },
    { 'Global', 'color_global' },
  })
end

function M.dynamic()
  return block({
    { 'Edit', 'dynamic_edit' },
    { 'Global', 'dynamic_global' },
  })
end

function M.blend()
  return block({
    { 'Adjust', 'blend_adjust' },
    { 'Set', 'blend_set' },
    { 'Global', 'blend_global' },
  })
end

function M.group()
  return block({
    { 'Action', 'group_action' },
    { 'Global', 'group_global' },
  })
end

return M
