local numbers = require('hlcraft.core.number')

--- @type table
local M = {}

local ellipsis = '…'

local function assert_text(value)
  if type(value) ~= 'string' then
    error('render text must be a string', 3)
  end
  return value
end

local function assert_width(value)
  if type(value) ~= 'number' then
    error('render width must be a number', 3)
  end
  if not numbers.is_finite(value) or math.floor(value) ~= value or value < 0 then
    error('render width must be a non-negative finite integer', 3)
  end
  return value
end

local function assert_line_nr(value)
  if type(value) ~= 'number' then
    error('render line number must be a number', 3)
  end
  if not numbers.is_finite(value) or math.floor(value) ~= value or value < 1 then
    error('render line number must be a positive finite integer', 3)
  end
  return value
end

local function take_display_width(text, width)
  if width <= 0 then
    return ''
  end

  local taken = {}
  local display_width = 0
  for index = 0, vim.fn.strchars(text) - 1 do
    local char = vim.fn.strcharpart(text, index, 1)
    local char_width = vim.fn.strdisplaywidth(char)
    if display_width + char_width > width then
      break
    end
    taken[#taken + 1] = char
    display_width = display_width + char_width
  end
  return table.concat(taken)
end

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
--- @param text string Text to truncate
--- @param width integer Maximum display width
--- @return string Truncated text
function M.truncate(text, width)
  text = assert_text(text)
  width = assert_width(width)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  if width == 0 then
    return ''
  end
  return take_display_width(text, width - vim.fn.strdisplaywidth(ellipsis)) .. ellipsis
end

--- Pad text to a given display width by appending spaces.
--- @param text string Text to pad
--- @param width integer Target display width
--- @return string Padded text
function M.pad(text, width)
  text = assert_text(text)
  width = assert_width(width)
  local display = vim.fn.strdisplaywidth(text)
  if display >= width then
    return text
  end
  return text .. string.rep(' ', width - display)
end

--- Return a rendered line by 1-based line number.
--- @param lines string[] Rendered lines
--- @param line_nr integer 1-based line number
--- @param label string|nil Error label for diagnostics
--- @return string line
function M.line_at(lines, line_nr, label)
  if type(lines) ~= 'table' then
    error('render lines must be a table', 2)
  end
  line_nr = assert_line_nr(line_nr)
  local line = lines[line_nr]
  if type(line) ~= 'string' then
    error(('%s references missing render line %d'):format(label or 'geometry', line_nr), 2)
  end
  return line
end

return M
