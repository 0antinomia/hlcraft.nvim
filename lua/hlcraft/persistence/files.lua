local codec = require('hlcraft.persistence.codec')

local M = {}

local uv = vim.uv

local function assert_string(value, label)
  if type(value) ~= 'string' then
    error(('%s must be a string'):format(label), 3)
  end
  return value
end

local function assert_lines(value)
  if type(value) ~= 'table' then
    error('File content lines must be a table', 3)
  end
  for index, line in ipairs(value) do
    if type(line) ~= 'string' then
      error(('File content line %d must be a string'):format(index), 3)
    end
  end
  return value
end

local function optional_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error('TOML directory options must be a table', 3)
  end
  return opts
end

function M.sanitize_filename(name)
  local sanitized = assert_string(name, 'Filename'):gsub('[^%w._-]', function(char)
    return ('_%02X'):format(string.byte(char))
  end)

  if sanitized == '' then
    sanitized = 'default'
  end

  return sanitized
end

function M.ensure_directory(path)
  assert_string(path, 'Directory path')
  vim.fn.mkdir(path, 'p')
end

function M.file_path(path, group_name)
  assert_string(path, 'Directory path')
  local section_name = codec.normalize_group_name(group_name)
  if not section_name then
    return nil
  end
  return path .. '/' .. M.sanitize_filename(section_name) .. '.toml'
end

local function is_toml_file(path, file_type, include_links)
  if file_type == 'file' then
    return true
  end
  if include_links and file_type == 'link' then
    local stat = uv.fs_stat(path)
    return stat and stat.type == 'file'
  end
  return false
end

function M.toml_files_in_dir(path, opts)
  assert_string(path, 'Directory path')
  opts = optional_opts(opts)
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

    local file_path = path .. '/' .. name
    if name:sub(-5) == '.toml' and is_toml_file(file_path, file_type, opts.include_links) then
      files[#files + 1] = file_path
    end
  end

  table.sort(files)
  return files
end

function M.atomic_write(filepath, content_lines)
  assert_string(filepath, 'File path')
  content_lines = assert_lines(content_lines)

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

function M.remove_stale_toml_files(path, active_section_names)
  assert_string(path, 'Directory path')
  if type(active_section_names) ~= 'table' then
    error('Active section names must be a table', 2)
  end

  local active_files = {}
  for _, section_name in ipairs(active_section_names) do
    active_files[M.sanitize_filename(section_name) .. '.toml'] = true
  end
  for _, file in ipairs(M.toml_files_in_dir(path)) do
    local basename = file:match('([^/]+)$')
    if basename and not active_files[basename] then
      os.remove(file)
    end
  end
end

return M
