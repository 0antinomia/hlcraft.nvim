local M = {}

local function string_list(lines, label)
  if type(lines) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  for _, line in ipairs(lines) do
    if type(line) ~= 'string' then
      error(('%s entries must be strings'):format(label), 3)
    end
  end
  return lines
end

local function editor_rows(geometry)
  if type(geometry) ~= 'table' then
    error('editor row geometry must be a table', 3)
  end
  if type(geometry.editor_rows) ~= 'table' then
    error('editor row geometry editor_rows must be a table', 3)
  end
  return geometry.editor_rows
end

local function non_empty_string(value, label)
  if type(value) ~= 'string' or value == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return value
end

function M.append(lines, geometry, key, text)
  lines = string_list(lines, 'editor row lines')
  local rows = editor_rows(geometry)
  key = non_empty_string(key, 'editor row key')
  text = non_empty_string(text, 'editor row text')
  local row = {
    line = #lines + 1,
    key = key,
  }
  rows[key] = row
  lines[#lines + 1] = text
  return row
end

return M
