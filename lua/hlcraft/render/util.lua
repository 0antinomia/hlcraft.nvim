--- @type table
local M = {}

--- Format a color value for display in result rows and detail views.
--- @param value string|nil Color value (#RRGGBB, NONE, etc.)
--- @return string Formatted display string
function M.display_color(value)
  if value and value ~= 'NONE' then
    return (' %s '):format(value)
  end
  return ' NONE '
end

--- Truncate text to fit within a given display width, appending ellipsis.
--- @param text string|nil Text to truncate
--- @param width integer Maximum display width
--- @return string Truncated text
function M.truncate(text, width)
  text = tostring(text or '')
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  if width <= 1 then
    return text:sub(1, width)
  end
  return text:sub(1, width - 1) .. '…'
end

--- Pad text to a given display width by appending spaces.
--- @param text string|nil Text to pad
--- @param width integer Target display width
--- @return string Padded text
function M.pad(text, width)
  text = tostring(text or '-')
  local display = vim.fn.strdisplaywidth(text)
  if display >= width then
    return text
  end
  return text .. string.rep(' ', width - display)
end

return M
