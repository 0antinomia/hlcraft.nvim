local render_util = require('hlcraft.render.util')

local M = {}

local function string_list(lines, label)
  return render_util.string_list(lines, label, 3)
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
  if rows[key] ~= nil then
    error(('editor row key already exists: %s'):format(key), 3)
  end
  local row = {
    line = #lines + 1,
    key = key,
  }
  rows[key] = row
  lines[#lines + 1] = text
  return row
end

return M
