local tables = require('hlcraft.core.tables')

local M = {}

local function format_value(value, indent)
  indent = indent or 0
  local pad = string.rep('  ', indent)
  local child_pad = string.rep('  ', indent + 1)

  if type(value) ~= 'table' then
    return vim.json.encode(value)
  end

  if next(value) == nil then
    return '{}'
  end

  local lines = {}
  if tables.is_sequence(value) then
    lines[#lines + 1] = '['
    for index, item in ipairs(value) do
      local comma = index < #value and ',' or ''
      lines[#lines + 1] = child_pad .. format_value(item, indent + 1) .. comma
    end
    lines[#lines + 1] = pad .. ']'
    return table.concat(lines, '\n')
  end

  lines[#lines + 1] = '{'
  local keys = tables.sorted_keys(value)
  for index, key in ipairs(keys) do
    local comma = index < #keys and ',' or ''
    lines[#lines + 1] = child_pad
      .. vim.json.encode(tostring(key))
      .. ': '
      .. format_value(value[key], indent + 1)
      .. comma
  end
  lines[#lines + 1] = pad .. '}'
  return table.concat(lines, '\n')
end

function M.format(value)
  return format_value(value, 0)
end

function M.decode_object(text)
  text = tostring(text or '')
  if not text:match('^%s*{') then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, text)
  if not ok or type(decoded) ~= 'table' then
    return nil
  end
  return decoded
end

return M
