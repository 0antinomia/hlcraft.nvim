local h = require('tests.helpers')
local scope = 'hlcraft persistence transaction'

local files = require('hlcraft.persistence.files')
local storage = require('hlcraft.persistence.repository')

local function is_temp_path(path, filepath)
  local prefix = filepath .. '.tmp.'
  return path:sub(1, #prefix) == prefix
end

do
  local dir = h.temp_dir('hlcraft-persistence-temp-cleanup-failure')
  vim.fn.mkdir(dir, 'p')
  local first_path = files.file_path(dir, 'aa')
  local failing_path = files.file_path(dir, 'zz')
  local first_temp
  local original_open = io.open
  local original_remove = os.remove

  io.open = function(path, mode)
    local file, err = original_open(path, mode)
    if is_temp_path(path, first_path) and file then
      first_temp = path
    elseif is_temp_path(path, failing_path) and file then
      return {
        write = function()
          return nil, 'write failed'
        end,
        close = function()
          return file:close()
        end,
      }
    end
    return file, err
  end
  os.remove = function(path)
    if path == first_temp then
      return nil, 'remove failed'
    end
    return original_remove(path)
  end

  local save_ok
  local save_err
  local call_ok, call_err = xpcall(function()
    save_ok, save_err = storage.save({
      FirstTemp = { fg = '#111111' },
      FailingTemp = { fg = '#222222' },
    }, {
      FirstTemp = 'aa',
      FailingTemp = 'zz',
    }, dir)
  end, debug.traceback)
  io.open = original_open
  os.remove = original_remove
  if not call_ok then
    error(call_err, 0)
  end

  local leaked_temps = vim.fn.glob(first_path .. '.tmp.*', false, true)
  for _, path in ipairs(leaked_temps) do
    original_remove(path)
  end
  h.cleanup_dir(dir)

  h.assert_true(not save_ok, 'storage.save accepted a failed staging write', scope)
  h.assert_true(
    save_err:find('Failed to remove temp file', 1, true) ~= nil,
    'staging cleanup failure omitted the leaked temp path',
    scope
  )
  h.assert_equal(#leaked_temps, 1, 'staging cleanup failure did not preserve the failed temp file', scope)
end

do
  local dir = h.temp_dir('hlcraft-persistence-atomic-commit-cleanup-failure')
  vim.fn.mkdir(dir, 'p')
  local filepath = dir .. '/active.toml'
  local original_rename = os.rename
  local original_remove = os.remove
  os.rename = function(source, target)
    if is_temp_path(source, filepath) and target == filepath then
      return nil, 'rename failed'
    end
    return original_rename(source, target)
  end
  os.remove = function(path)
    if is_temp_path(path, filepath) then
      return nil, 'remove failed'
    end
    return original_remove(path)
  end

  local write_ok
  local write_err
  local call_ok, call_err = xpcall(function()
    local staged, temp_or_err = files.write_temp(filepath, { 'new content' })
    if not staged then
      error(temp_or_err, 0)
    end
    write_ok, write_err = files.commit_temp(filepath, temp_or_err)
  end, debug.traceback)
  os.rename = original_rename
  os.remove = original_remove
  if not call_ok then
    error(call_err, 0)
  end

  local leaked_temps = vim.fn.glob(filepath .. '.tmp.*', false, true)
  for _, path in ipairs(leaked_temps) do
    original_remove(path)
  end
  h.cleanup_dir(dir)

  h.assert_true(not write_ok, 'commit_temp accepted a failed commit', scope)
  h.assert_true(
    write_err:find('Failed to remove temp file', 1, true) ~= nil,
    'atomic commit cleanup failure omitted the leaked temp path',
    scope
  )
  h.assert_equal(#leaked_temps, 1, 'atomic commit cleanup failure did not preserve the failed temp file', scope)
end

do
  local dir = h.temp_dir('hlcraft-persistence-temp-close-cleanup-failure')
  vim.fn.mkdir(dir, 'p')
  local filepath = dir .. '/active.toml'
  local original_open = io.open
  local original_chmod = vim.uv.fs_chmod
  io.open = function(path, mode)
    local file, err = original_open(path, mode)
    if is_temp_path(path, filepath) and file then
      return {
        write = function(_, text)
          return file:write(text)
        end,
        close = function()
          file:close()
          return nil, 'close failed'
        end,
      }
    end
    return file, err
  end
  vim.uv.fs_chmod = function(path, ...)
    if is_temp_path(path, filepath) then
      return nil, 'chmod failed', 'EACCES'
    end
    return original_chmod(path, ...)
  end

  local write_ok
  local write_err
  local call_ok, call_err = xpcall(function()
    write_ok, write_err = files.write_temp(filepath, { 'new content' })
  end, debug.traceback)
  io.open = original_open
  vim.uv.fs_chmod = original_chmod
  if not call_ok then
    error(call_err, 0)
  end

  local leaked_temps = vim.fn.glob(filepath .. '.tmp.*', false, true)
  for _, path in ipairs(leaked_temps) do
    os.remove(path)
  end
  h.cleanup_dir(dir)

  h.assert_true(not write_ok, 'write_temp accepted a failed chmod', scope)
  h.assert_true(
    write_err:find('Failed to close temp file', 1, true) ~= nil,
    'temp close cleanup failure omitted the close error',
    scope
  )
  h.assert_equal(#leaked_temps, 0, 'temp close cleanup failure kept a removed temp file', scope)
end

do
  local dir = h.temp_dir('hlcraft-persistence-preserve-mode')
  vim.fn.mkdir(dir, 'p')
  local path = files.file_path(dir, 'private')
  h.write_file(path, {
    '["private"]',
    '"PrivateBefore" = { fg = "#101010" }',
  })
  vim.uv.fs_chmod(path, 384)
  local save_ok, save_err = storage.save({
    PrivateAfter = { fg = '#202020' },
  }, {
    PrivateAfter = 'private',
  }, dir)
  local mode = vim.uv.fs_stat(path).mode % 512
  h.cleanup_dir(dir)

  h.assert_true(save_ok, save_err or 'storage.save rejected a private TOML file', scope)
  h.assert_equal(mode, 384, 'storage.save broadened TOML file permissions', scope)
end

do
  local dir = h.temp_dir('hlcraft-persistence-hardlink-target')
  vim.fn.mkdir(dir, 'p')
  local path = files.file_path(dir, 'active')
  local alias = dir .. '/alias.toml'
  local original = '["active"]\n"HardlinkBefore" = { fg = "#101010" }\n'
  h.write_file(path, {
    '["active"]',
    '"HardlinkBefore" = { fg = "#101010" }',
  })
  local linked, link_err = vim.uv.fs_link(path, alias)
  h.assert_true(linked, ('failed to create hardlink fixture: %s'):format(tostring(link_err)), scope)
  local save_ok, save_err = storage.save({
    HardlinkAfter = { fg = '#202020' },
  }, {
    HardlinkAfter = 'active',
  }, dir)
  local path_content = h.read_file(path)
  local alias_content = h.read_file(alias)
  h.cleanup_dir(dir)

  h.assert_true(not save_ok, 'storage.save accepted a hard-linked TOML target', scope)
  h.assert_true(
    type(save_err) == 'string' and save_err:find('hard-linked', 1, true) ~= nil,
    'hard-linked TOML rejection returned the wrong error',
    scope
  )
  h.assert_equal(path_content, original, 'hard-linked TOML rejection changed target content', scope)
  h.assert_equal(alias_content, original, 'hard-linked TOML rejection changed alias content', scope)
end

do
  local dir = h.temp_dir('hlcraft-persistence-backup-recovery')
  vim.fn.mkdir(dir, 'p')
  local path = files.file_path(dir, 'active')
  h.write_file(path .. '.bak', {
    '["active"]',
    '"InterruptedSave" = { fg = "#101010" }',
  })
  local save_ok, save_err = storage.save({
    RecoveredSave = { fg = '#202020' },
  }, {
    RecoveredSave = 'active',
  }, dir)
  local backup_exists = vim.uv.fs_lstat(path .. '.bak') ~= nil
  local content = h.read_file(path)
  h.cleanup_dir(dir)

  h.assert_true(save_ok, save_err or 'storage.save rejected an interrupted backup', scope)
  h.assert_true(not backup_exists, 'storage.save kept a recovered canonical backup', scope)
  h.assert_true(
    content:find('RecoveredSave', 1, true) ~= nil,
    'storage.save did not commit after recovering a canonical backup',
    scope
  )
end

print('hlcraft persistence transaction: OK')
