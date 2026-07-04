local M = {}

local function assert_string(value, message)
  if type(value) ~= 'string' then
    error(message, 3)
  end
end

local function keycap(item)
  return ('[%s]'):format(item[1])
end

local function keycap_width(items)
  local width = 0
  for _, item in ipairs(items or {}) do
    width = math.max(width, vim.fn.strdisplaywidth(keycap(item)))
  end
  return width
end

local function item_line(item, width)
  local key = keycap(item)
  local padding = math.max(2, (width or 0) - vim.fn.strdisplaywidth(key) + 2)
  return '  ' .. key .. string.rep(' ', padding) .. item[2]
end

function M.sections(preview_key)
  local action_items = {
    { 's', 'save draft' },
  }
  local navigation_items = {
    { 'q / Esc', 'back/close' },
    { '?', 'help' },
    { 'Tab', 'next input' },
    { 'S-Tab', 'previous input' },
  }

  if preview_key ~= nil and preview_key ~= false then
    assert_string(preview_key, 'preview key must be a string or false')
    if preview_key ~= '' then
      action_items[#action_items + 1] = { preview_key, 'preview result' }
    end
  end

  return {
    {
      title = 'Navigation',
      items = navigation_items,
    },
    {
      title = 'Actions',
      items = action_items,
    },
    {
      title = 'Search',
      items = {
        { 'Enter', 'open/apply' },
        { 'j/k', 'move' },
        { 'J/K', 'next/prev result' },
        { 'gr', 'first result' },
      },
    },
    {
      title = 'Detail',
      items = {
        { 'Enter', 'edit/toggle' },
      },
    },
    {
      title = 'Static color',
      items = {
        { 'i', 'input value' },
        { 'r/R', 'red' },
        { 'g/G', 'green' },
        { 'b/B', 'blue' },
        { 'n', 'set NONE' },
        { 'd', 'dynamic' },
      },
    },
    {
      title = 'Dynamic color',
      items = {
        { 'i', 'edit row' },
        { 'm', 'cycle preset' },
        { '+/-', 'duration / phase row' },
        { 'e', 'raw JSON' },
        { 'd', 'static' },
      },
    },
    {
      title = 'Blend editor',
      items = {
        { '-/+', 'small step' },
        { '</>', 'large step' },
        { 'u', 'unset blend' },
        { 'i', 'input value' },
      },
    },
    {
      title = 'Group editor',
      items = {
        { 'Enter', 'select group' },
        { 'i', 'input group' },
      },
    },
  }
end

function M.lines(preview_key)
  local lines = {
    'hlcraft help',
    '',
  }

  local sections = M.sections(preview_key)
  for section_index, section in ipairs(sections) do
    lines[#lines + 1] = section.title
    local width = keycap_width(section.items)
    for _, item in ipairs(section.items) do
      lines[#lines + 1] = item_line(item, width)
    end
    if section_index < #sections then
      lines[#lines + 1] = ''
    end
  end

  return lines
end

function M.is_item_line(line)
  assert_string(line, 'help line must be a string')
  return line:find('^%s*%b[]%s+') ~= nil
end

return M
