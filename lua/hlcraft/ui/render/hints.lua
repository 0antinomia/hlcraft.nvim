local M = {}

local separator = '  |  '
local groups = {
  search = {
    { 'Enter', 'open/apply' },
    { 'Tab', 'input' },
    { '?', 'more' },
  },
  detail = {
    { 'Enter', 'edit/toggle' },
    { 's', 'save' },
    { '?', 'more' },
  },
  color_adjust = {
    { 'r/R', 'red' },
    { 'g/G', 'green' },
    { 'b/B', 'blue' },
    { 'n', 'NONE' },
    { 'i', 'input' },
  },
  color_global = {
    { 'd', 'dynamic' },
    { 's', 'save' },
    { 'q', 'back' },
    { '?', 'more' },
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
    { '?', 'more' },
  },
  blend_adjust = {
    { '-/+', 'small' },
    { '</>', 'large' },
    { 'u', 'unset' },
    { 'i', 'input' },
  },
  blend_global = {
    { 's', 'save' },
    { 'q', 'back' },
    { '?', 'more' },
  },
  group = {
    { 'Enter', 'select' },
    { 'i', 'input' },
    { 's', 'save' },
    { '?', 'more' },
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
  return label .. ': ' .. M.format(groups[group])
end

function M.search()
  return M.format(groups.search)
end

function M.detail()
  return M.format(groups.detail)
end

function M.color_adjust()
  return section('Adjust', 'color_adjust')
end

function M.color_global()
  return section('Global', 'color_global')
end

function M.dynamic_edit()
  return section('Edit', 'dynamic_edit')
end

function M.dynamic_global()
  return section('Global', 'dynamic_global')
end

function M.blend_adjust()
  return section('Adjust', 'blend_adjust')
end

function M.blend_global()
  return section('Global', 'blend_global')
end

function M.group()
  return M.format(groups.group)
end

return M
