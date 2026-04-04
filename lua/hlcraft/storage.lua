--- @type table
local M = {}

local config = require('hlcraft.config')

local uv = vim.uv

local function storage_dir()
  return config.config.persist_dir
end

local function escape_string(value)
  return tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
end

local function unescape_string(value)
  return tostring(value):gsub('\\"', '"'):gsub('\\\\', '\\')
end

local function normalize_group_name(name)
  local normalized = vim.trim(tostring(name or ''))
  if normalized == '' then
    return config.default_group_name()
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

  return normalize_group_name(section_name)
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
      local key, raw = vim.trim(field):match('^(%w+)%s*=%s*(.+)$')
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

local function encode_inline_table(entry)
  local parts = {}
  local keys = vim.tbl_keys(entry)
  table.sort(keys)

  for _, key in ipairs(keys) do
    local encoded = encode_scalar(entry[key])
    if encoded ~= nil then
      parts[#parts + 1] = ('%s = %s'):format(key, encoded)
    end
  end

  return ('{ %s }'):format(table.concat(parts, ', '))
end

local function sanitize_filename(name)
  local sanitized = tostring(name):gsub('[^%w._-]', function(char)
    return ('_%02X'):format(string.byte(char))
  end)

  if sanitized == '' then
    sanitized = 'default'
  end

  return sanitized
end

local function ensure_directory(path)
  vim.fn.mkdir(path, 'p')
end

local function load_file(target, data)
  local file = io.open(target, 'r')
  if not file then
    return
  end

  local current_section = nil

  for line in file:lines() do
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

  file:close()
end

local function toml_files_in_dir(path)
  local files = {}
  local fd = uv.fs_scandir(path)
  if not fd then
    return files
  end

  while true do
    local name, file_type = uv.fs_scandir_next(fd)
    if not name then
      break
    end

    if file_type == 'file' and name:sub(-5) == '.toml' then
      files[#files + 1] = path .. '/' .. name
    end
  end

  table.sort(files)
  return files
end

local function remove_existing_toml_files(path)
  for _, file in ipairs(toml_files_in_dir(path)) do
    os.remove(file)
  end
end

local function atomic_write_file(filepath, content_lines)
  local tmp_path = filepath .. '.tmp'
  local file, open_err = io.open(tmp_path, 'w')
  if not file then
    return false, ('Failed to create temp file %s: %s'):format(tmp_path, tostring(open_err))
  end
  for _, line in ipairs(content_lines) do
    file:write(line .. '\n')
  end
  file:close()
  local _, rename_err = os.rename(tmp_path, filepath)
  if rename_err then
    os.remove(tmp_path)
    return false, ('Failed to rename temp file: %s'):format(tostring(rename_err))
  end
  return true, nil
end

local function remove_stale_toml_files(path, active_section_names)
  local active_files = {}
  for _, section_name in ipairs(active_section_names) do
    active_files[sanitize_filename(section_name) .. '.toml'] = true
  end
  for _, file in ipairs(toml_files_in_dir(path)) do
    local basename = file:match('([^/]+)$')
    if basename and not active_files[basename] then
      os.remove(file)
    end
  end
end

--- Return the persisted override directory path.
--- @return string
function M.path()
  return storage_dir()
end

--- Return the persisted TOML file path for one top-level group.
--- @param group_name string|nil
--- @return string
function M.file_path(group_name)
  local section_name = normalize_group_name(group_name)
  return storage_dir() .. '/' .. sanitize_filename(section_name) .. '.toml'
end

--- Load persisted highlight overrides from a directory of TOML files.
--- @param path string|nil
--- @return table
function M.load(path)
  local target = path or storage_dir()
  local stat = uv.fs_stat(target)
  if not stat or stat.type ~= 'directory' then
    return {
      entries = {},
      groups = {},
      sections = {},
    }
  end

  local data = {
    entries = {},
    groups = {},
    sections = {},
  }

  for _, file in ipairs(toml_files_in_dir(target)) do
    load_file(file, data)
  end

  return data
end

--- Save persisted highlight overrides into one TOML file per top-level group.
--- @param overrides table
--- @param groups table|nil
--- @param path string|nil
--- @return boolean ok
--- @return string|nil err
function M.save(overrides, groups, path)
  local target = path or storage_dir()
  ensure_directory(target)

  local sections = {}

  for highlight_name, entry in pairs(overrides or {}) do
    if entry and next(entry) ~= nil then
      local section_name = normalize_group_name(groups and groups[highlight_name])
      sections[section_name] = sections[section_name] or {}
      sections[section_name][highlight_name] = entry
    end
  end

  local section_names = vim.tbl_keys(sections)
  table.sort(section_names)

  for _, section_name in ipairs(section_names) do
    local file_name = sanitize_filename(section_name) .. '.toml'
    local filepath = target .. '/' .. file_name
    local lines = {
      '# Generated by hlcraft.nvim',
      '# Example: ["default"] then "Normal" = { fg = "#c8d3f5", bg = "NONE" }',
      '# Manual edits are preserved if they follow the grouped inline-table TOML shape.',
      '',
      ('["%s"]'):format(escape_string(section_name)),
    }

    local highlight_names = vim.tbl_keys(sections[section_name])
    table.sort(highlight_names)

    for _, highlight_name in ipairs(highlight_names) do
      lines[#lines + 1] = ('"%s" = %s'):format(
        escape_string(highlight_name),
        encode_inline_table(sections[section_name][highlight_name])
      )
    end

    local ok, err = atomic_write_file(filepath, lines)
    if not ok then
      return false, err
    end
  end

  remove_stale_toml_files(target, section_names)

  return true, nil
end

return M
