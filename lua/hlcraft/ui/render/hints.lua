local M = {}

local separator = '  |  '

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

function M.search()
  return M.format({
    { 'Enter', 'open/apply' },
    { 'Tab', 'input' },
    { '?', 'more' },
  })
end

function M.detail()
  return M.format({
    { 'Enter', 'edit/toggle' },
    { 's', 'save' },
    { '?', 'more' },
  })
end

function M.color_adjust()
  return 'Adjust: '
    .. M.format({
      { 'r/R', 'red' },
      { 'g/G', 'green' },
      { 'b/B', 'blue' },
      { 'n', 'NONE' },
      { 'i', 'input' },
    })
end

function M.color_global()
  return 'Global: '
    .. M.format({
      { 'd', 'dynamic' },
      { 's', 'save' },
      { 'q', 'back' },
      { '?', 'more' },
    })
end

function M.dynamic_edit()
  return 'Edit: '
    .. M.format({
      { 'i', 'row' },
      { 'm', 'preset' },
      { '+/-', 'time/phase' },
      { 'e', 'JSON' },
    })
end

function M.dynamic_global()
  return 'Global: '
    .. M.format({
      { 'd', 'static' },
      { 's', 'save' },
      { 'q', 'back' },
      { '?', 'more' },
    })
end

function M.blend_adjust()
  return 'Adjust: '
    .. M.format({
      { '-/+', 'small' },
      { '</>', 'large' },
      { 'u', 'unset' },
      { 'i', 'input' },
    })
end

function M.blend_global()
  return 'Global: ' .. M.format({
    { 's', 'save' },
    { 'q', 'back' },
    { '?', 'more' },
  })
end

function M.group()
  return M.format({
    { 'Enter', 'select' },
    { 'i', 'input' },
    { 's', 'save' },
    { '?', 'more' },
  })
end

return M
