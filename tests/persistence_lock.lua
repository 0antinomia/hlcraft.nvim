local h = require('tests.helpers')
local scope = 'hlcraft persistence lock'

local files = require('hlcraft.persistence.files')
local storage = require('hlcraft.persistence.repository')

do
  local dir = h.temp_dir('hlcraft-persistence-lock-release-failure')
  vim.fn.mkdir(dir, 'p')
  local lock_path = dir .. '/.hlcraft.save.lock'
  local original_unlink = vim.uv.fs_unlink
  vim.uv.fs_unlink = function(path, ...)
    if path == lock_path then
      return nil, 'unlink failed', 'EACCES'
    end
    return original_unlink(path, ...)
  end

  local save_ok
  local save_err
  local call_ok, call_err = xpcall(function()
    save_ok, save_err = storage.save({
      LockReleaseFailure = { fg = '#111111' },
    }, {
      LockReleaseFailure = 'active',
    }, dir)
  end, debug.traceback)
  vim.uv.fs_unlink = original_unlink
  if not call_ok then
    error(call_err, 0)
  end

  h.assert_true(not save_ok, 'storage.save ignored a failed lock release', scope)
  h.assert_true(
    type(save_err) == 'string' and save_err:find('Failed to release persistence save lock', 1, true) ~= nil,
    'storage.save returned the wrong lock release error',
    scope
  )
  h.assert_file_exists(lock_path, 'failed lock release lost the live lock file', scope)
  original_unlink(lock_path)
  h.cleanup_dir(dir)
end

do
  local dir = h.temp_dir('hlcraft-persistence-lock-ownership')
  vim.fn.mkdir(dir, 'p')
  local acquired, lock_or_err = files.acquire_save_lock(dir)
  h.assert_true(acquired, lock_or_err or 'failed to acquire ownership test lock', scope)
  local lock = lock_or_err
  local foreign_owner = tostring(vim.uv.os_getpid()) .. ':deadbeef'
  h.write_file(lock.path, { foreign_owner })

  local released, release_err = files.release_save_lock(lock)
  local lock_exists = vim.uv.fs_lstat(lock.path) ~= nil
  local lock_content = lock_exists and h.read_file(lock.path) or nil
  if lock_exists then
    vim.uv.fs_unlink(lock.path)
  end
  h.cleanup_dir(dir)

  h.assert_true(not released, 'lock release removed a lock with changed ownership', scope)
  h.assert_true(
    type(release_err) == 'string' and release_err:find('ownership changed', 1, true) ~= nil,
    'changed lock ownership returned the wrong error',
    scope
  )
  h.assert_true(lock_exists, 'lock release removed the replacement lock file', scope)
  h.assert_equal(lock_content, foreign_owner .. '\n', 'lock release changed the replacement lock content', scope)
end

do
  local dir = h.temp_dir('hlcraft-persistence-lock-disappeared')
  vim.fn.mkdir(dir, 'p')
  local acquired, lock_or_err = files.acquire_save_lock(dir)
  h.assert_true(acquired, lock_or_err or 'failed to acquire disappearing lock fixture', scope)
  local lock = lock_or_err
  vim.uv.fs_unlink(lock.path)

  local released, release_err = files.release_save_lock(lock)
  h.cleanup_dir(dir)

  h.assert_true(not released, 'lock release accepted a disappeared lock file', scope)
  h.assert_true(
    type(release_err) == 'string' and release_err:find('disappeared', 1, true) ~= nil,
    'disappeared lock returned the wrong error',
    scope
  )
end

do
  local dir = h.temp_dir('hlcraft-persistence-lock-malformed')
  vim.fn.mkdir(dir, 'p')
  local lock_path = dir .. '/.hlcraft.save.lock'
  h.write_file(lock_path, { 'not-a-lock-owner' })

  local save_ok, save_err = storage.save({}, {}, dir)
  local lock_content = h.read_file(lock_path)
  h.cleanup_dir(dir)

  h.assert_true(not save_ok, 'storage.save accepted a malformed save lock', scope)
  h.assert_true(
    type(save_err) == 'string' and save_err:find('invalid owner data', 1, true) ~= nil,
    'malformed save lock returned the wrong error',
    scope
  )
  h.assert_equal(lock_content, 'not-a-lock-owner\n', 'malformed save lock recovery changed the lock file', scope)
end

do
  local dir = h.temp_dir('hlcraft-persistence-lock-stale-replacement')
  vim.fn.mkdir(dir, 'p')
  local lock_path = dir .. '/.hlcraft.save.lock'
  local dead_owner = 2147483647
  local foreign_owner = tostring(vim.uv.os_getpid()) .. ':feedface'
  h.write_file(lock_path, { tostring(dead_owner) .. ':deadbeef' })
  local original_kill = vim.uv.kill
  vim.uv.kill = function(pid, signal)
    if pid == dead_owner and signal == 0 then
      vim.uv.fs_unlink(lock_path)
      h.write_file(lock_path, { foreign_owner })
      return nil, 'no such process', 'ESRCH'
    end
    return original_kill(pid, signal)
  end

  local acquired
  local lock_or_err
  local call_ok, call_err = xpcall(function()
    acquired, lock_or_err = files.acquire_save_lock(dir)
  end, debug.traceback)
  vim.uv.kill = original_kill
  if not call_ok then
    error(call_err, 0)
  end

  local lock_content = vim.uv.fs_lstat(lock_path) and h.read_file(lock_path) or nil
  if acquired then
    files.release_save_lock(lock_or_err)
  elseif vim.uv.fs_lstat(lock_path) then
    vim.uv.fs_unlink(lock_path)
  end
  h.cleanup_dir(dir)

  h.assert_true(not acquired, 'stale lock recovery removed a replacement lock', scope)
  h.assert_true(
    type(lock_or_err) == 'string' and lock_or_err:find('changed while recovering', 1, true) ~= nil,
    'stale replacement lock returned the wrong error',
    scope
  )
  h.assert_equal(lock_content, foreign_owner .. '\n', 'stale lock recovery changed the replacement lock', scope)
end

do
  local dir = h.temp_dir('hlcraft-persistence-lock-create-cleanup-failure')
  vim.fn.mkdir(dir, 'p')
  local lock_path = dir .. '/.hlcraft.save.lock'
  local original_write = vim.uv.fs_write
  local original_unlink = vim.uv.fs_unlink
  vim.uv.fs_write = function()
    return 0, 'short write', 'EIO'
  end
  vim.uv.fs_unlink = function(path, ...)
    if path == lock_path then
      return nil, 'unlink failed', 'EACCES'
    end
    return original_unlink(path, ...)
  end

  local acquired
  local acquire_err
  local call_ok, call_err = xpcall(function()
    acquired, acquire_err = files.acquire_save_lock(dir)
  end, debug.traceback)
  vim.uv.fs_write = original_write
  vim.uv.fs_unlink = original_unlink
  if not call_ok then
    error(call_err, 0)
  end

  local lock_exists = vim.uv.fs_lstat(lock_path) ~= nil
  if lock_exists then
    original_unlink(lock_path)
  end
  h.cleanup_dir(dir)

  h.assert_true(not acquired, 'save lock accepted a short owner write', scope)
  h.assert_true(
    acquire_err:find('Failed to remove incomplete persistence save lock', 1, true) ~= nil,
    'save lock creation cleanup failure omitted the live lock path',
    scope
  )
  h.assert_true(lock_exists, 'save lock creation cleanup failure did not preserve the failed lock file', scope)
end

do
  local dir = h.temp_dir('hlcraft-persistence-lock-reentry')
  vim.fn.mkdir(dir, 'p')
  local original_write_temp = files.write_temp
  local nested_started = false
  local nested_ok
  local nested_err
  files.write_temp = function(...)
    local write_ok, temp_or_err = original_write_temp(...)
    if write_ok and not nested_started then
      nested_started = true
      nested_ok, nested_err = storage.save({
        NestedSave = { fg = '#222222' },
      }, {
        NestedSave = 'active',
      }, dir)
    end
    return write_ok, temp_or_err
  end

  local outer_ok
  local outer_err
  local call_ok, call_err = xpcall(function()
    outer_ok, outer_err = storage.save({
      OuterSave = { fg = '#111111' },
    }, {
      OuterSave = 'active',
    }, dir)
  end, debug.traceback)
  files.write_temp = original_write_temp
  if not call_ok then
    error(call_err, 0)
  end

  local content = h.read_file(files.file_path(dir, 'active'))
  h.cleanup_dir(dir)

  h.assert_true(outer_ok, outer_err or 'outer storage.save failed', scope)
  h.assert_true(not nested_ok, 'storage.save accepted an interleaved save', scope)
  h.assert_true(
    type(nested_err) == 'string' and nested_err:find('already in progress', 1, true) ~= nil,
    'interleaved storage.save returned the wrong error',
    scope
  )
  h.assert_true(
    content:find('OuterSave', 1, true) ~= nil and content:find('NestedSave', 1, true) == nil,
    'interleaved storage.save committed the wrong transaction',
    scope
  )
end

do
  local dir = h.temp_dir('hlcraft-persistence-lock-alias-reentry')
  local alias = dir .. '-alias'
  vim.fn.mkdir(dir, 'p')
  h.cleanup_dir(alias)
  local linked, link_err = vim.uv.fs_symlink(dir, alias)
  h.assert_true(linked, ('failed to create lock alias fixture: %s'):format(tostring(link_err)), scope)

  local original_write_temp = files.write_temp
  local nested_started = false
  local nested_ok
  local nested_err
  files.write_temp = function(...)
    local write_ok, temp_or_err = original_write_temp(...)
    if write_ok and not nested_started then
      nested_started = true
      nested_ok, nested_err = storage.save({
        AliasNestedSave = { fg = '#222222' },
      }, {
        AliasNestedSave = 'active',
      }, alias)
    end
    return write_ok, temp_or_err
  end

  local outer_ok
  local outer_err
  local call_ok, call_err = xpcall(function()
    outer_ok, outer_err = storage.save({
      AliasOuterSave = { fg = '#111111' },
    }, {
      AliasOuterSave = 'active',
    }, dir)
  end, debug.traceback)
  files.write_temp = original_write_temp
  if not call_ok then
    error(call_err, 0)
  end

  local content = h.read_file(files.file_path(dir, 'active'))
  vim.uv.fs_unlink(alias)
  h.cleanup_dir(dir)

  h.assert_true(outer_ok, outer_err or 'outer aliased storage.save failed', scope)
  h.assert_true(not nested_ok, 'storage.save accepted an interleaved aliased save', scope)
  h.assert_true(
    type(nested_err) == 'string' and nested_err:find('already in progress', 1, true) ~= nil,
    'interleaved aliased storage.save returned the wrong error',
    scope
  )
  h.assert_true(
    content:find('AliasOuterSave', 1, true) ~= nil and content:find('AliasNestedSave', 1, true) == nil,
    'interleaved aliased storage.save committed the wrong transaction',
    scope
  )
end

print('hlcraft persistence lock: OK')
