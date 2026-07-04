local util = require('hlcraft.persistence.codec.util')

local M = {}

local supported_escapes = {
  ['"'] = true,
  ['\\'] = true,
}

local function parse_quoted_token(text, index)
  if text:sub(index, index) ~= '"' then
    return nil, index
  end

  local parts = {}
  local i = index + 1

  while i <= #text do
    local char = text:sub(i, i)
    if char == '\\' then
      if i >= #text then
        return nil, index
      end
      local escaped_char = text:sub(i + 1, i + 1)
      if not supported_escapes[escaped_char] then
        return nil, index
      end
      parts[#parts + 1] = text:sub(i, i + 1)
      i = i + 2
    elseif char == '"' then
      return util.unescape_string(table.concat(parts)), i + 1
    else
      parts[#parts + 1] = char
      i = i + 1
    end
  end

  return nil, index
end

local function parse_quoted_string(value)
  local parsed, next_index = parse_quoted_token(value, 1)
  if parsed ~= nil and next_index > #value then
    return parsed
  end
  return nil
end

local function split_top_level(text, separator)
  local parts = {}
  local current = {}
  local in_string = false
  local escaped = false
  local table_depth = 0
  local array_depth = 0

  for i = 1, #text do
    local char = text:sub(i, i)
    if escaped then
      current[#current + 1] = char
      escaped = false
    elseif char == '\\' and in_string then
      current[#current + 1] = char
      escaped = true
    elseif char == '"' then
      current[#current + 1] = char
      in_string = not in_string
    elseif not in_string and char == '{' then
      current[#current + 1] = char
      table_depth = table_depth + 1
    elseif not in_string and char == '}' then
      current[#current + 1] = char
      table_depth = math.max(0, table_depth - 1)
    elseif not in_string and char == '[' then
      current[#current + 1] = char
      array_depth = array_depth + 1
    elseif not in_string and char == ']' then
      current[#current + 1] = char
      array_depth = math.max(0, array_depth - 1)
    elseif char == separator and not in_string and table_depth == 0 and array_depth == 0 then
      parts[#parts + 1] = table.concat(current)
      current = {}
    else
      current[#current + 1] = char
    end
  end

  parts[#parts + 1] = table.concat(current)
  return parts
end

local parse_value

local function parse_array(text)
  local body = vim.trim(text:sub(2, -2))
  local result = {}
  if body == '' then
    return result
  end

  for _, raw_item in ipairs(split_top_level(body, ',')) do
    local value = parse_value(raw_item)
    if value == nil then
      return nil
    end
    result[#result + 1] = value
  end

  return result
end

local function parse_inline_table(text)
  local body = vim.trim(text:sub(2, -2))
  local entry = {}
  if body == '' then
    return entry
  end

  for _, field in ipairs(split_top_level(body, ',')) do
    local key, raw = vim.trim(field):match('^([%w_]+)%s*=%s*(.+)$')
    if not key or not raw then
      return nil
    end

    local value = parse_value(raw)
    if value == nil then
      return nil
    end
    if entry[key] ~= nil then
      return nil
    end
    entry[key] = value
  end

  return entry
end

parse_value = function(raw)
  local value = vim.trim(raw or '')

  if value == 'true' then
    return true
  end
  if value == 'false' then
    return false
  end
  if value:match('^%b{}$') then
    return parse_inline_table(value)
  end
  if value:match('^%b[]$') then
    return parse_array(value)
  end
  if value:sub(1, 1) == '"' then
    return parse_quoted_string(value)
  end

  local number_value = tonumber(value)
  if number_value ~= nil then
    return number_value
  end
  return nil
end

function M.section_header(text)
  local inner = text:match('^%[(.+)%]$')
  if not inner then
    return nil
  end

  local section_name, next_index = parse_quoted_token(inner, 1)
  if not section_name or next_index <= #inner then
    return nil
  end

  return util.normalize_group_name(section_name)
end

local function entry_parts(trimmed)
  if trimmed:sub(1, 1) == '"' then
    local key_part, next_index = parse_quoted_token(trimmed, 1)
    if not key_part then
      return nil, nil
    end

    local rest = vim.trim(trimmed:sub(next_index))
    return key_part, rest:match('^=%s*(%b{})%s*$')
  end

  return trimmed:match('^([%w_%-.@]+)%s*=%s*(%b{})%s*$')
end

function M.entry_line(text)
  local key_part, value_part = entry_parts(vim.trim(text))

  if not key_part or not value_part then
    return nil, nil
  end

  local entry = parse_value(value_part)
  if type(entry) ~= 'table' then
    return nil, nil
  end
  return key_part, entry
end

return M
