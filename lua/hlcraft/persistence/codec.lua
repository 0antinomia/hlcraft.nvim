local M = {}

local function escape_string(value)
  return tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
end

local function unescape_string(value)
  return tostring(value):gsub('\\"', '"'):gsub('\\\\', '\\')
end

function M.normalize_group_name(name)
  local normalized = vim.trim(tostring(name or ''))
  if normalized == '' then
    return nil
  end

  return normalized
end

local function parse_scalar(raw)
  local value = vim.trim(raw or '')

  if value == 'true' then
    return true
  end

  if value == 'false' then
    return false
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
    elseif char == separator and not in_string then
      parts[#parts + 1] = table.concat(current)
      current = {}
    else
      current[#current + 1] = char
    end
  end

  parts[#parts + 1] = table.concat(current)
  return parts
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
        entry[key] = parse_scalar(raw)
      end
    end
  end

  return key_part, entry
end

local function encode_scalar(value)
  if type(value) == 'string' then
    return ('"%s"'):format(escape_string(value))
  end

  if type(value) == 'boolean' then
    return value and 'true' or 'false'
  end

  if type(value) == 'number' then
    return tostring(value)
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

function M.encode_inline_table(entry)
  local parts = {}
  local keys = vim.tbl_keys(entry or {})
  table.sort(keys)

  for _, key in ipairs(keys) do
    local encoded = encode_scalar(entry[key])
    if encoded ~= nil then
      parts[#parts + 1] = ('%s = %s'):format(key, encoded)
    end
  end

  return ('{ %s }'):format(table.concat(parts, ', '))
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
