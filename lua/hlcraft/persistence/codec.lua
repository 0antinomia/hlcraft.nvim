local encoder = require('hlcraft.persistence.codec.encoder')
local parser = require('hlcraft.persistence.codec.parser')
local util = require('hlcraft.persistence.codec.util')

local M = {}

M.normalize_group_name = util.normalize_group_name
M.encode_inline_table = encoder.inline_table

local function assert_string(value, label)
  if type(value) ~= 'string' then
    error(('%s must be a string'):format(label), 3)
  end
  return value
end

local function assert_lines(value)
  if type(value) ~= 'table' then
    error('TOML lines must be a table', 3)
  end
  for index, line in ipairs(value) do
    if type(line) ~= 'string' then
      error(('TOML line %d must be a string'):format(index), 3)
    end
  end
  return value
end

local function assert_data(value)
  if value == nil then
    return M.empty_data()
  end
  if type(value) ~= 'table' then
    error('TOML data must be a table', 3)
  end
  for _, key in ipairs({ 'entries', 'groups', 'sections' }) do
    if type(value[key]) ~= 'table' then
      error(('TOML data %s must be a table'):format(key), 3)
    end
  end
  return value
end

function M.empty_data()
  return {
    entries = {},
    groups = {},
    sections = {},
  }
end

local function ensure_section(data, section_name)
  if data.sections[section_name] == nil then
    data.sections[section_name] = {}
  end
  return data.sections[section_name]
end

function M.decode_lines(lines, data)
  lines = assert_lines(lines)
  data = assert_data(data)
  local current_section = nil

  for line_number, line in ipairs(lines) do
    local text = vim.trim(line)
    if text ~= '' and not text:match('^#') then
      local section_name = parser.section_header(text)
      if section_name then
        current_section = section_name
        ensure_section(data, current_section)
      elseif text:sub(1, 1) == '[' then
        error(('Invalid TOML section at line %d'):format(line_number), 2)
      else
        if not current_section then
          error(('TOML entry before section at line %d'):format(line_number), 2)
        end
        local highlight_name, entry = parser.entry_line(text)
        if not highlight_name or not entry then
          error(('Invalid TOML entry at line %d'):format(line_number), 2)
        end
        data.sections[current_section][highlight_name] = entry
        data.entries[highlight_name] = entry
        data.groups[highlight_name] = current_section
      end
    end
  end

  return data
end

function M.load_file(target, data)
  target = assert_string(target, 'TOML file path')
  data = assert_data(data)
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

M.encode_section = encoder.section

return M
