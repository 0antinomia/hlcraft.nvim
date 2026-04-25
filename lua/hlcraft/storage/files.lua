local codec = require('hlcraft.storage.codec')

local M = {}

local uv = vim.uv

function M.sanitize_filename(name)
  local sanitized = tostring(name):gsub('[^%w._-]', function(char)
    return ('_%02X'):format(string.byte(char))
  end)

  if sanitized == '' then
    sanitized = 'default'
  end

  return sanitized
end

function M.ensure_directory(path)
  vim.fn.mkdir(path, 'p')
end

function M.file_path(path, group_name)
  local section_name = codec.normalize_group_name(group_name)
  if not section_name then
    return nil
  end
  return path .. '/' .. M.sanitize_filename(section_name) .. '.toml'
end

function M.toml_files_in_dir(path)
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

function M.atomic_write(filepath, content_lines)
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
