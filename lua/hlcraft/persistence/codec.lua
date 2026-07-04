local M = {}

local function escape_string(value)
  return tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
end

local function unescape_string(value)
  return tostring(value):gsub('\\"', '"'):gsub('\\\\', '\\')
end

local key_priority = {
  fg = 10,
  bg = 20,
  sp = 30,
  bold = 40,
  italic = 50,
  underline = 60,
  undercurl = 70,
  strikethrough = 80,
  underdouble = 90,
  underdotted = 100,
  underdashed = 110,
  blend = 120,
  dynamic = 130,
  version = 140,
  preset = 150,
  duration = 160,
  loop = 170,
  phase = 180,
  type = 185,
  interpolation = 190,
  timeline = 200,
  transforms = 210,
  at = 230,
  color = 240,
  value = 250,
}

function M.normalize_group_name(name)
  local normalized = vim.trim(tostring(name or ''))
  if normalized == '' then
    return nil
  end

  return normalized
end

local function parse_quoted_token(text, index)
  if text:sub(index, index) ~= '"' then
    return nil, index
  end

  local parts = {}
  local i = index + 1

  while i <= #text do
    local char = text:sub(i, i)
    if char == '\\' and i < #text then
      parts[#parts + 1] = text:sub(i, i + 1)
      i = i + 2
    elseif char == '"' then
      return unescape_string(table.concat(parts)), i + 1
    else
      parts[#parts + 1] = char
      i = i + 1
    end
  end

  return nil, index
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

  if value:match('^".*"$') then
    return unescape_string(value:sub(2, -2))
  end

  local number_value = tonumber(value)
  if number_value ~= nil then
    return number_value
  end

  return value
end

local function parse_section_header(text)
  local inner = text:match('^%[(.+)%]$')
  if not inner then
    return nil
  end

  local section_name, next_index = parse_quoted_token(inner, 1)
  if not section_name or next_index <= #inner then
    return nil
  end

  return M.normalize_group_name(section_name)
end

local function parse_entry_line(text)
  local trimmed = vim.trim(text)
  local key_part = nil
  local value_part = nil

  if trimmed:sub(1, 1) == '"' then
    local next_index
    key_part, next_index = parse_quoted_token(trimmed, 1)
    if not key_part then
      return nil, nil
    end

    local rest = vim.trim(trimmed:sub(next_index))
    value_part = rest:match('^=%s*(%b{})%s*$')
  else
    key_part, value_part = trimmed:match('^([%w_%-.@]+)%s*=%s*(%b{})%s*$')
  end

  if not key_part or not value_part then
    return nil, nil
  end

  local body = vim.trim(value_part:sub(2, -2))
  local entry = {}

  if body ~= '' then
    for _, field in ipairs(split_top_level(body, ',')) do
      local key, raw = vim.trim(field):match('^([%w_]+)%s*=%s*(.+)$')
      if key and raw then
        local value = parse_value(raw)
        if value ~= nil then
          entry[key] = value
        end
      end
    end
  end

  return key_part, entry
end

local function is_array(value)
  if type(value) ~= 'table' then
    return false
  end

  local count = 0
  for key, _ in pairs(value) do
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
      return false
    end
    count = count + 1
  end

  return count == #value
end

local function ordered_keys(entry)
  local keys = vim.tbl_keys(entry or {})
  table.sort(keys, function(left, right)
    local left_priority = key_priority[left] or math.huge
    local right_priority = key_priority[right] or math.huge
    if left_priority == right_priority then
      return tostring(left) < tostring(right)
    end
    return left_priority < right_priority
  end)
  return keys
end

local encode_value

local function encode_array(values)
  local parts = {}
  for _, value in ipairs(values) do
    local encoded = encode_value(value)
    if encoded == nil then
      return nil
    end
    parts[#parts + 1] = encoded
  end
  return ('[%s]'):format(table.concat(parts, ', '))
end

function M.encode_inline_table(entry)
  local parts = {}
  for _, key in ipairs(ordered_keys(entry)) do
    local encoded = encode_value(entry[key])
    if encoded ~= nil then
      parts[#parts + 1] = ('%s = %s'):format(key, encoded)
    end
  end

  return ('{ %s }'):format(table.concat(parts, ', '))
end

encode_value = function(value)
  if type(value) == 'string' then
    return ('"%s"'):format(escape_string(value))
  end

  if type(value) == 'boolean' then
    return value and 'true' or 'false'
  end

  if type(value) == 'number' then
    return tostring(value)
  end

  if type(value) == 'table' then
    if is_array(value) then
      return encode_array(value)
    end
    return M.encode_inline_table(value)
  end

  return nil
end

function M.empty_data()
  return {
    entries = {},
    groups = {},
    sections = {},
  }
end

function M.decode_lines(lines, data)
  data = data or M.empty_data()
  local current_section = nil

  for _, line in ipairs(lines or {}) do
    local text = vim.trim(line)
    if text ~= '' and not text:match('^#') then
      local section_name = parse_section_header(text)
      if section_name then
        current_section = section_name
        data.sections[current_section] = data.sections[current_section] or {}
      elseif current_section then
        local highlight_name, entry = parse_entry_line(text)
        if highlight_name and entry then
          data.sections[current_section][highlight_name] = entry
          data.entries[highlight_name] = entry
          data.groups[highlight_name] = current_section
        end
      end
    end
  end

  return data
end

function M.load_file(target, data)
  local file = io.open(target, 'r')
  if not file then
    return data
  end

  local lines = {}
  for line in file:lines() do
    lines[#lines + 1] = line
  end
  file:close()

  return M.decode_lines(lines, data)
end

function M.encode_section(section_name, entries)
  local lines = {
    ('["%s"]'):format(escape_string(section_name)),
  }
  local highlight_names = vim.tbl_keys(entries or {})
  table.sort(highlight_names)

  for _, highlight_name in ipairs(highlight_names) do
    lines[#lines + 1] = ('"%s" = %s'):format(
      escape_string(highlight_name),
      M.encode_inline_table(entries[highlight_name])
    )
  end

  return lines
end

return M
