local encoder = require('hlcraft.persistence.codec.encoder')
local parser = require('hlcraft.persistence.codec.parser')
local util = require('hlcraft.persistence.codec.util')

local M = {}

M.normalize_group_name = util.normalize_group_name
M.encode_inline_table = encoder.inline_table

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
      local section_name = parser.section_header(text)
      if section_name then
        current_section = section_name
        data.sections[current_section] = data.sections[current_section] or {}
      elseif current_section then
        local highlight_name, entry = parser.entry_line(text)
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

M.encode_section = encoder.section

return M
