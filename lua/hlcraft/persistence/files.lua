local codec = require('hlcraft.persistence.codec')
local tables = require('hlcraft.core.tables')

local M = {}

local uv = vim.uv
local active_save_locks = {}

local function assert_string(value, label)
  if type(value) ~= 'string' then
    error(('%s must be a string'):format(label), 3)
  end
  return value
end

local function assert_path(value, label)
  if type(value) ~= 'string' then
    error(('%s must be a string'):format(label), 3)
  end
  if vim.trim(value) == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return value
end

local function assert_lines(value)
  value = tables.assert_sequence(value, 'File content lines', 3)
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

local function toml_directory_opts(opts)
  opts = optional_opts(opts)
  for key in pairs(opts) do
    if key ~= 'include_links' and key ~= 'include_broken_links' then
      error(('Unknown TOML directory option: %s'):format(tostring(key)), 3)
    end
  end
  if opts.include_links ~= nil and type(opts.include_links) ~= 'boolean' then
    error('TOML directory include_links must be boolean', 3)
  end
  if opts.include_broken_links ~= nil and type(opts.include_broken_links) ~= 'boolean' then
    error('TOML directory include_broken_links must be boolean', 3)
  end
  return opts
end

local function stale_cleanup_opts(opts)
  opts = optional_opts(opts)
  for key in pairs(opts) do
    if key ~= 'protected_paths' and key ~= 'defer_backup_finalization' then
      error(('Unknown stale TOML cleanup option: %s'):format(tostring(key)), 3)
    end
  end
  if opts.defer_backup_finalization ~= nil and type(opts.defer_backup_finalization) ~= 'boolean' then
    error('Stale TOML cleanup defer_backup_finalization must be boolean', 3)
  end
  if opts.protected_paths ~= nil then
    opts.protected_paths = tables.assert_sequence(opts.protected_paths, 'Protected TOML paths', 3)
    for index, protected_path in ipairs(opts.protected_paths) do
      assert_path(protected_path, ('Protected TOML path %d'):format(index))
    end
  else
    opts.protected_paths = {}
  end
  return opts
end

local function protected_path_maps(paths)
  local exact_paths = {}
  local real_paths = {}
  for _, path in ipairs(paths) do
    exact_paths[path] = true
    local realpath = uv.fs_realpath(path)
    if realpath then
      real_paths[realpath] = true
    end
  end
  return exact_paths, real_paths
end

local function is_protected_path(path, exact_paths, real_paths)
  if exact_paths[path] then
    return true
  end

  local stat = uv.fs_lstat(path)
  if stat and stat.type ~= 'link' then
    local realpath = uv.fs_realpath(path)
    return realpath ~= nil and real_paths[realpath] == true
  end
  return false
end

local function random_hex(size)
  local bytes, err = uv.random(size)
  if not bytes then
    return nil, err
  end
  return (bytes:gsub('.', function(byte)
    return ('%02x'):format(string.byte(byte))
  end))
end

local function append_rollback_errors(err, rollback_errors)
  if #rollback_errors == 0 then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, table.concat(rollback_errors, '; '))
end

function M.sanitize_filename(name)
  local sanitized = assert_string(name, 'Filename'):gsub('[^%w%.%-]', function(char)
    return ('_%02X'):format(string.byte(char))
  end)

  if sanitized == '' then
    sanitized = 'default'
  end

  return sanitized
end

function M.ensure_directory(path)
  assert_path(path, 'Directory path')
  local ok, result = pcall(vim.fn.mkdir, path, 'p')
  if not ok or result == 0 then
    return false, ('Failed to create directory %s: %s'):format(path, tostring(result))
  end
  return true, nil
end

function M.file_path(path, group_name)
  assert_path(path, 'Directory path')
  local section_name = codec.normalize_group_name(group_name)
  if not section_name then
    return nil
  end
  return path .. '/' .. M.sanitize_filename(section_name) .. '.toml'
end

function M.validate_write_target(filepath)
  filepath = assert_path(filepath, 'File path')
  local stat = uv.fs_lstat(filepath)
  if stat and stat.type ~= 'file' and stat.type ~= 'link' then
    return false, ('Cannot write TOML file %s: path is a %s'):format(filepath, stat.type)
  end
  local target_stat = uv.fs_stat(filepath)
  if target_stat and target_stat.type == 'file' and target_stat.nlink > 1 then
    return false, ('Cannot write hard-linked TOML file %s'):format(filepath)
  end
  return true, nil
end

function M.write_target_path(filepath)
  filepath = assert_path(filepath, 'File path')
  local stat = uv.fs_lstat(filepath)
  if not stat then
    return filepath, nil
  end
  if stat.type == 'file' then
    return uv.fs_realpath(filepath) or filepath, nil
  end
  if stat.type ~= 'link' then
    return nil, ('Cannot write TOML file %s: path is a %s'):format(filepath, stat.type)
  end

  local resolved = uv.fs_realpath(filepath)
  local target_stat = uv.fs_stat(filepath)
  if not resolved or not target_stat then
    return nil, ('Cannot write TOML file %s: symlink target is missing'):format(filepath)
  end
  if target_stat.type ~= 'file' then
    return nil, ('Cannot write TOML file %s: symlink target is a %s'):format(filepath, target_stat.type)
  end
  return resolved, nil
end

function M.path_identity(path)
  path = assert_path(path, 'File path')
  local stat = uv.fs_stat(path)
  if not stat then
    return nil
  end
  if stat.dev ~= nil and stat.ino ~= nil then
    return ('%s:%s'):format(tostring(stat.dev), tostring(stat.ino))
  end
  return uv.fs_realpath(path) or path
end

function M.recover_write_backup(filepath)
  filepath = assert_path(filepath, 'File path')
  if uv.fs_lstat(filepath) then
    return true, nil
  end
  local backup = filepath .. '.bak'
  local backup_stat = uv.fs_lstat(backup)
  if not backup_stat then
    return true, nil
  end
  if backup_stat.type ~= 'file' and backup_stat.type ~= 'link' then
    return false, ('Cannot recover TOML backup %s: path is a %s'):format(backup, backup_stat.type)
  end
  local recovered, err = os.rename(backup, filepath)
  if not recovered then
    return false, ('Failed to recover TOML backup %s: %s'):format(backup, tostring(err))
  end
  return true, nil
end

local function read_lock_token(lock_path)
  local file, open_err = io.open(lock_path, 'r')
  if not file then
    return nil, open_err
  end
  local content, read_err = file:read('*a')
  file:close()
  if type(content) ~= 'string' then
    return nil, read_err or 'failed to read lock content'
  end
  return vim.trim(content), nil
end

local function lock_owner(lock_path)
  local token, read_err = read_lock_token(lock_path)
  if token == nil then
    return nil, nil, ('unreadable owner data: %s'):format(tostring(read_err))
  end
  local owner = token:match('^(%d+):[%da-f]+$') or token:match('^(%d+)$')
  owner = tonumber(owner)
  if owner == nil or owner < 1 or owner > 2147483647 or owner ~= math.floor(owner) then
    return nil, nil, 'invalid owner data'
  end
  return owner, token, nil
end

local function process_is_alive(pid)
  local result, _, code = uv.kill(pid, 0)
  return result == 0 or code == 'EPERM'
end

local function create_save_lock(lock_path, pid)
  local nonce, random_err = random_hex(16)
  if not nonce then
    return false, random_err, 'EIO'
  end
  local fd, open_err, open_code = uv.fs_open(lock_path, 'wx', 384)
  if not fd then
    return false, open_err, open_code
  end
  local token = ('%d:%s'):format(pid, nonce)
  local written, write_err = uv.fs_write(fd, token, 0)
  local closed, close_err = uv.fs_close(fd)
  if written ~= #token or not closed then
    local removed, remove_err = uv.fs_unlink(lock_path)
    local rollback_errors = {}
    if not removed and uv.fs_lstat(lock_path) then
      rollback_errors[#rollback_errors + 1] = ('Failed to remove incomplete persistence save lock %s: %s'):format(
        lock_path,
        tostring(remove_err)
      )
    end
    return false, append_rollback_errors(write_err or close_err or 'short lock write', rollback_errors), 'EIO'
  end
  return true, token, nil
end

function M.acquire_save_lock(path)
  path = assert_path(path, 'Directory path')
  local lock_path = (uv.fs_realpath(path) or path) .. '/.hlcraft.save.lock'
  if active_save_locks[lock_path] then
    return false, ('Persistence save is already in progress for %s'):format(path)
  end

  local pid = uv.os_getpid()
  for _ = 1, 2 do
    local created, token_or_err, code = create_save_lock(lock_path, pid)
    if created then
      active_save_locks[lock_path] = token_or_err
      return true, {
        path = lock_path,
        token = token_or_err,
      }
    end
    if code ~= 'EEXIST' then
      return false, ('Failed to acquire persistence save lock %s: %s'):format(lock_path, tostring(token_or_err))
    end

    local owner, observed_token, owner_err = lock_owner(lock_path)
    if owner == nil then
      return false, ('Persistence save lock %s has %s'):format(lock_path, owner_err)
    end
    if owner == pid or not process_is_alive(owner) then
      local current_token, read_err = read_lock_token(lock_path)
      if current_token ~= observed_token then
        local detail = read_err and (': ' .. tostring(read_err)) or ''
        return false, ('Persistence save lock changed while recovering %s%s'):format(lock_path, detail)
      end
      local removed, remove_err = uv.fs_unlink(lock_path)
      if not removed and uv.fs_lstat(lock_path) then
        return false, ('Failed to recover persistence save lock %s: %s'):format(lock_path, tostring(remove_err))
      end
    else
      return false, ('Persistence save is already in progress for %s'):format(path)
    end
  end
  return false, ('Failed to acquire persistence save lock %s'):format(lock_path)
end

function M.release_save_lock(lock)
  if type(lock) ~= 'table' then
    error('Persistence save lock must be a table', 2)
  end
  local lock_path = assert_path(lock.path, 'Persistence save lock path')
  local expected_token = assert_path(lock.token, 'Persistence save lock token')
  local current_token, read_err = read_lock_token(lock_path)
  if current_token == nil and not uv.fs_lstat(lock_path) then
    active_save_locks[lock_path] = nil
    return false, ('Persistence save lock disappeared before release: %s'):format(lock_path)
  end
  if current_token ~= expected_token then
    active_save_locks[lock_path] = nil
    local detail = read_err and (': ' .. tostring(read_err)) or ''
    return false, ('Persistence save lock ownership changed for %s%s'):format(lock_path, detail)
  end

  active_save_locks[lock_path] = nil
  local removed, err = uv.fs_unlink(lock_path)
  if not removed then
    if uv.fs_lstat(lock_path) then
      return false, ('Failed to release persistence save lock %s: %s'):format(lock_path, tostring(err))
    end
    return false, ('Persistence save lock disappeared during release: %s'):format(lock_path)
  end
  return true, nil
end

function M.remove_temp(temp_path)
  temp_path = assert_path(temp_path, 'Temp file path')
  local ok, err = os.remove(temp_path)
  if not ok and uv.fs_lstat(temp_path) then
    return false, ('Failed to remove temp file %s: %s'):format(temp_path, tostring(err))
  end
  return true, nil
end

local function stale_backup_path(filepath)
  return filepath .. '.bak'
end

local function finalized_backup_path(backup)
  local base = backup .. '.cleanup'
  if not uv.fs_lstat(base) then
    return base
  end

  local index = 1
  while true do
    local candidate = ('%s.%d'):format(base, index)
    if not uv.fs_lstat(candidate) then
      return candidate
    end
    index = index + 1
  end
end

local function restore_finalized_backups(finalized)
  local errors = {}
  for index = #finalized, 1, -1 do
    local item = finalized[index]
    local ok, err = os.rename(item.finalized, item.backup)
    if not ok then
      errors[#errors + 1] = ('Failed to restore finalized TOML backup %s: %s'):format(item.backup, tostring(err))
    end
  end
  return errors
end

function M.finalize_backup_paths(backups, label)
  backups = tables.assert_sequence(backups, 'Backup paths', 2)
  label = label or 'TOML backup'
  local finalized = {}
  for _, backup in ipairs(backups) do
    backup = assert_path(backup, 'Backup path')
    local finalized_path = finalized_backup_path(backup)
    local ok, err = os.rename(backup, finalized_path)
    if not ok then
      return false,
        append_rollback_errors(
          ('Failed to finalize %s %s: %s'):format(label, backup, tostring(err)),
          restore_finalized_backups(finalized)
        )
    end
    finalized[#finalized + 1] = {
      backup = backup,
      finalized = finalized_path,
    }
  end

  for _, item in ipairs(finalized) do
    pcall(os.remove, item.finalized)
  end
  return true, nil
end

local function prepare_stale_backup(filepath)
  local backup = stale_backup_path(filepath)
  if uv.fs_lstat(backup) then
    return false, ('Cannot remove stale TOML file %s: backup already exists'):format(filepath)
  end
  local renamed, rename_err = os.rename(filepath, backup)
  if not renamed then
    return false, ('Failed to back up stale TOML file %s: %s'):format(filepath, tostring(rename_err))
  end
  return true, {
    filepath = filepath,
    backup = backup,
  }
end

local function restore_stale_backup(item)
  if uv.fs_lstat(item.filepath) then
    return M.finalize_backup_paths({ item.backup }, 'stale TOML backup')
  end

  local ok, err = os.rename(item.backup, item.filepath)
  if not ok then
    return false, ('Failed to restore stale TOML file %s: %s'):format(item.filepath, tostring(err))
  end
  return true, nil
end

local function rollback_stale_backups(backups)
  local errors = {}
  for index = #backups, 1, -1 do
    local ok, err = restore_stale_backup(backups[index])
    if not ok then
      errors[#errors + 1] = err
    end
  end
  return errors
end

local function stale_backup_paths(backups)
  local paths = {}
  for _, item in ipairs(backups) do
    paths[#paths + 1] = item.backup
  end
  return paths
end

function M.stale_toml_backup_paths(backups)
  backups = tables.assert_sequence(backups, 'Stale TOML backups', 2)
  return stale_backup_paths(backups)
end

function M.rollback_stale_toml_backups(backups)
  backups = tables.assert_sequence(backups, 'Stale TOML backups', 2)
  return rollback_stale_backups(backups)
end

local function is_toml_file(path, file_type, opts)
  if file_type == 'file' then
    return true
  end
  if opts.include_links and file_type == 'link' then
    local stat = uv.fs_stat(path)
    if stat then
      return stat.type == 'file'
    end
    return opts.include_broken_links == true
  end
  return false
end

function M.toml_files_in_dir(path, opts)
  assert_path(path, 'Directory path')
  opts = toml_directory_opts(opts)
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
    if name:sub(-5) == '.toml' and is_toml_file(file_path, file_type, opts) then
      files[#files + 1] = file_path
    end
  end

  table.sort(files)
  return files
end

local function open_temp(filepath)
  for _ = 1, 16 do
    local suffix, random_err = random_hex(12)
    if not suffix then
      return nil, nil, ('Failed to generate temp file name for %s: %s'):format(filepath, tostring(random_err))
    end
    local temp_path = ('%s.tmp.%s'):format(filepath, suffix)
    local file, open_err = io.open(temp_path, 'wx')
    if file then
      return file, temp_path, nil
    end
    if not uv.fs_lstat(temp_path) then
      return nil, nil, ('Failed to create temp file %s: %s'):format(temp_path, tostring(open_err))
    end
  end
  return nil, nil, ('Failed to allocate a unique temp file for %s'):format(filepath)
end

local function close_temp(file, temp_path)
  local call_ok, closed, close_err = pcall(file.close, file)
  if not call_ok then
    return false, ('Failed to close temp file %s: %s'):format(temp_path, tostring(closed))
  end
  if not closed then
    return false, ('Failed to close temp file %s: %s'):format(temp_path, tostring(close_err))
  end
  return true, nil
end

local function cleanup_open_temp(file, temp_path)
  local errors = {}
  local closed, close_err = close_temp(file, temp_path)
  if not closed then
    errors[#errors + 1] = close_err
  end
  local removed, remove_err = M.remove_temp(temp_path)
  if not removed then
    errors[#errors + 1] = remove_err
  end
  return errors
end

function M.write_temp(filepath, content_lines)
  assert_path(filepath, 'File path')
  content_lines = assert_lines(content_lines)
  local target_stat = uv.fs_stat(filepath)
  local mode = target_stat and target_stat.mode % 512 or 384

  local file, temp_path, open_err = open_temp(filepath)
  if not file then
    return false, open_err
  end
  local mode_ok, mode_err = uv.fs_chmod(temp_path, mode)
  if not mode_ok then
    local err = ('Failed to set temp file permissions %s: %s'):format(temp_path, tostring(mode_err))
    return false, append_rollback_errors(err, cleanup_open_temp(file, temp_path))
  end
  for _, line in ipairs(content_lines) do
    local write_ok, write_err = file:write(line .. '\n')
    if not write_ok then
      local err = ('Failed to write temp file %s: %s'):format(temp_path, tostring(write_err))
      return false, append_rollback_errors(err, cleanup_open_temp(file, temp_path))
    end
  end
  local close_ok, close_err = close_temp(file, temp_path)
  if not close_ok then
    local removed, remove_err = M.remove_temp(temp_path)
    return false, append_rollback_errors(close_err, removed and {} or { remove_err })
  end
  return true, temp_path
end

function M.commit_temp(filepath, temp_path)
  assert_path(filepath, 'File path')
  temp_path = assert_path(temp_path, 'Temp file path')
  local _, rename_err = os.rename(temp_path, filepath)
  if rename_err then
    local removed, remove_err = M.remove_temp(temp_path)
    local err = ('Failed to rename temp file: %s'):format(tostring(rename_err))
    return false, append_rollback_errors(err, removed and {} or { remove_err })
  end
  return true, nil
end

function M.remove_stale_toml_files(path, active_section_names, opts)
  assert_path(path, 'Directory path')
  active_section_names = tables.assert_sequence(active_section_names, 'Active section names', 2)
  opts = stale_cleanup_opts(opts)

  local active_files = {}
  for _, section_name in ipairs(active_section_names) do
    active_files[M.sanitize_filename(section_name) .. '.toml'] = true
  end
  local protected_exact_paths, protected_real_paths = protected_path_maps(opts.protected_paths)
  local stale_files = {}
  for _, file in ipairs(M.toml_files_in_dir(path, { include_links = true, include_broken_links = true })) do
    local basename = file:match('([^/]+)$')
    local protected = is_protected_path(file, protected_exact_paths, protected_real_paths)
    if basename and not active_files[basename] and not protected then
      stale_files[#stale_files + 1] = file
    end
  end

  local backups = {}
  for _, file in ipairs(stale_files) do
    local prepared, backup_or_err = prepare_stale_backup(file)
    if not prepared then
      return false, append_rollback_errors(backup_or_err, rollback_stale_backups(backups))
    end
    backups[#backups + 1] = backup_or_err
  end

  if opts.defer_backup_finalization then
    return true, backups
  end
  local finalized, finalize_err = M.finalize_backup_paths(stale_backup_paths(backups), 'stale TOML backup')
  if not finalized then
    return false, append_rollback_errors(finalize_err, rollback_stale_backups(backups))
  end
  return true, nil
end

return M
