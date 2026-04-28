local M = {}

local config = require('hlcraft.config')
local dynamic_model = require('hlcraft.dynamic.model')
local codec = require('hlcraft.storage.codec')
local files = require('hlcraft.storage.files')

local function storage_dir()
  return config.config.persist_dir
end

--- Return the persisted override directory path.
--- @return string
function M.path()
  return storage_dir()
end

--- Return the persisted TOML file path for one top-level group.
--- @param group_name string|nil
--- @return string|nil
function M.file_path(group_name)
  return files.file_path(storage_dir(), group_name)
end

local function inflate_entries(data)
  for name, entry in pairs(data.entries or {}) do
    data.entries[name] = dynamic_model.inflate_entry(entry)
  end
  return data
end

local function flatten_entries(entries)
  local flattened = {}
  for name, entry in pairs(entries or {}) do
    flattened[name] = dynamic_model.flatten_entry(entry)
  end
  return flattened
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
      parts[#parts + 1] = text:sub(i + 1, i + 1)
      i = i + 2
    elseif char == '"' then
      return table.concat(parts), i + 1
    else
      parts[#parts + 1] = char
      i = i + 1
    end
  end

  return nil, index
end

local function parse_scalar(raw)
  local value = vim.trim(raw or '')
  if value:match('^".*"$') then
    return select(1, parse_quoted_token(value, 1))
  end
  return tonumber(value) or value
end

local function split_top_level(text)
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
    elseif char == ',' and not in_string then
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

  return codec.normalize_group_name(section_name)
end

local function parse_entry_body(text)
  local trimmed = vim.trim(text)
  local highlight_name = nil
  local body = nil

  if trimmed:sub(1, 1) == '"' then
    local next_index
    highlight_name, next_index = parse_quoted_token(trimmed, 1)
    if highlight_name then
      body = vim.trim(trimmed:sub(next_index)):match('^=%s*{(.*)}%s*$')
    end
  else
    highlight_name, body = trimmed:match('^([%w_%-.@]+)%s*=%s*{(.*)}%s*$')
  end

  return highlight_name, body
end

local function merge_dynamic_keys_from_file(target, data)
  local file = io.open(target, 'r')
  if not file then
    return data
  end

  local current_section = nil
  for line in file:lines() do
    local text = vim.trim(line)
    if text ~= '' and not text:match('^#') then
      current_section = parse_section_header(text) or current_section
      if current_section then
        local highlight_name, body = parse_entry_body(text)
        local entry = highlight_name and data.entries[highlight_name] or nil
        if entry and body then
          for _, field in ipairs(split_top_level(body)) do
            local key, raw = vim.trim(field):match('^(dyn_%w+_%w+)%s*=%s*(.+)$')
            local channel, kind = nil, nil
            if key then
              channel, kind = key:match('^dyn_(%w+)_(%w+)$')
            end
            if dynamic_model.channel_set[channel] and (kind == 'mode' or kind == 'speed') then
              entry[key] = parse_scalar(raw)
              if data.sections[current_section] and data.sections[current_section][highlight_name] then
                data.sections[current_section][highlight_name][key] = entry[key]
              end
            end
          end
        end
      end
    end
  end

  file:close()
  return data
end

--- Load persisted highlight overrides from a directory of TOML files.
--- @param path string|nil
--- @return table
function M.load(path)
  local target = path or storage_dir()
  local stat = vim.uv.fs_stat(target)
  if not stat or stat.type ~= 'directory' then
    return codec.empty_data()
  end

  local data = codec.empty_data()
  for _, file in ipairs(files.toml_files_in_dir(target)) do
    codec.load_file(file, data)
    merge_dynamic_keys_from_file(file, data)
  end

  return inflate_entries(data)
end

local function build_sections(overrides, groups)
  local sections = {}

  for highlight_name, entry in pairs(overrides or {}) do
    if entry and next(entry) ~= nil then
      local section_name = codec.normalize_group_name(groups and groups[highlight_name])
      if not section_name then
        return nil, ('Highlight %s must have a group before saving'):format(tostring(highlight_name))
      end
      sections[section_name] = sections[section_name] or {}
      sections[section_name][highlight_name] = entry
    end
  end

  for highlight_name, group_name in pairs(groups or {}) do
    local section_name = codec.normalize_group_name(group_name)
    if not section_name then
      return nil, ('Highlight %s must have a group before saving'):format(tostring(highlight_name))
    end
    sections[section_name] = sections[section_name] or {}
    sections[section_name][highlight_name] = sections[section_name][highlight_name]
      or (overrides and overrides[highlight_name])
      or {}
  end

  return sections, nil
end

--- Save persisted highlight overrides into one TOML file per top-level group.
--- @param overrides table
--- @param groups table|nil
--- @param path string|nil
--- @return boolean ok
--- @return string|nil err
function M.save(overrides, groups, path)
  local target = path or storage_dir()
  files.ensure_directory(target)

  local flattened_overrides = flatten_entries(overrides)
  local sections, section_err = build_sections(flattened_overrides, groups)
  if not sections then
    return false, section_err
  end

  local section_names = vim.tbl_keys(sections)
  table.sort(section_names)

  for _, section_name in ipairs(section_names) do
    local filepath = files.file_path(target, section_name)
    local lines = {
      '# Generated by hlcraft.nvim',
      '# Example: ["default"] then "Normal" = { fg = "#c8d3f5", bg = "NONE" }',
      '# Manual edits are preserved if they follow the grouped inline-table TOML shape.',
      '',
    }
    vim.list_extend(lines, codec.encode_section(section_name, sections[section_name]))

    local ok, err = files.atomic_write(filepath, lines)
    if not ok then
      return false, err
    end
  end

  files.remove_stale_toml_files(target, section_names)

  return true, nil
end

return M
