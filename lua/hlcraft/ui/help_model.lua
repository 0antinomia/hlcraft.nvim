local M = {}

local function item_line(item)
  return ('[%s] %s'):format(item[1], item[2])
end

function M.sections(preview_key)
  local global_items = {
    { 'q / Esc', 'back or close' },
    { '?', 'toggle this help' },
    { 's', 'save current draft when available' },
    { 'Tab', 'next input' },
    { 'S-Tab', 'previous input' },
  }

  if preview_key and preview_key ~= false and preview_key ~= '' then
    table.insert(global_items, 4, { tostring(preview_key), 'flash current result' })
  end

  return {
    {
      title = 'Global',
      items = global_items,
    },
    {
      title = 'Search',
      items = {
        { 'Enter', 'open selected result or apply input' },
        { 'j/k', 'move' },
      },
    },
    {
      title = 'Detail',
      items = {
        { 'Enter', 'edit field or toggle boolean' },
      },
    },
    {
      title = 'Static color editor',
      items = {
        { 'i', 'input value' },
        { 'r/R', 'decrease/increase red' },
        { 'g/G', 'decrease/increase green' },
        { 'b/B', 'decrease/increase blue' },
        { 'n', 'set NONE' },
        { 'd', 'switch to dynamic' },
      },
    },
    {
      title = 'Dynamic color editor',
      items = {
        { 'i', 'edit selected row or raw JSON' },
        { 'm', 'cycle preset' },
        { '+/-', 'adjust duration, or phase on the Phase row' },
        { 'e', 'edit raw JSON' },
        { 'd', 'switch to static' },
      },
    },
    {
      title = 'Blend editor',
      items = {
        { '-/+', 'small adjustment' },
        { '</>', 'large adjustment' },
        { 'u', 'unset blend' },
        { 'i', 'input value' },
      },
    },
    {
      title = 'Group editor',
      items = {
        { 'Enter', 'select group' },
        { 'i', 'input new group' },
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
    for _, item in ipairs(section.items) do
      lines[#lines + 1] = item_line(item)
    end
    if section_index < #sections then
      lines[#lines + 1] = ''
    end
  end

  return lines
end

function M.is_item_line(line)
  line = tostring(line or '')
  return line:find('^%s*%b[]%s+') ~= nil or line:find('%s%s+') ~= nil
end

return M
