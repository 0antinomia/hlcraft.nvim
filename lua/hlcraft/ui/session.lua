local dynamic_model = require('hlcraft.dynamic.model')
local engine = require('hlcraft.engine.service')
local fields = require('hlcraft.core.fields')
local highlight_names = require('hlcraft.core.highlight_names')

local M = {}

local function assert_name(name)
  return highlight_names.assert(name, 'highlight name', 3)
end

local function assert_key(key)
  if type(key) ~= 'string' or key == '' then
    error('session field key must be a non-empty string', 3)
  end
  return key
end

local function assert_entry(value, label)
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  return value
end

local function copy_entry(value, label)
  value = assert_entry(value, label)
  return vim.deepcopy(value)
end

local function same_entry(left, right)
  left = assert_entry(left, 'left session entry')
  right = assert_entry(right, 'right session entry')
  return vim.deep_equal(left, right)
end

local function assert_refresh_target(instance)
  if type(instance) ~= 'table' then
    error('session refresh requires an instance', 3)
  end
  if instance.state ~= nil and type(instance.state) ~= 'table' then
    error('session refresh state must be a table', 3)
  end
  if type(instance.rerender) ~= 'function' then
    error('session refresh requires a rerender callback', 3)
  end
  return instance
end

local function refresh(instance, name)
  if type(instance.state) == 'table' and type(instance.state.results) == 'table' then
    require('hlcraft.ui.scene.detail').refresh(instance, name, true)
  else
    instance:rerender()
  end
end

local function assert_engine_result(ok, err, fallback)
  if not ok then
    error(err or fallback, 0)
  end
end

local function restore_draft(name, entry, group)
  local patch = {
    group = group == nil and vim.NIL or group,
    dynamic = {},
  }
  for _, key in ipairs(fields.override_keys) do
    patch[key] = entry[key] == nil and vim.NIL or entry[key]
  end
  local dynamic = type(entry.dynamic) == 'table' and entry.dynamic or {}
  for _, key in ipairs(dynamic_model.channels) do
    patch.dynamic[key] = dynamic[key] == nil and vim.NIL or dynamic[key]
  end

  local ok, err = engine.apply_patch(name, patch)
  assert_engine_result(ok, err, 'failed to restore draft after refresh failure')
end

local function append_rollback_error(err, rollback_err)
  if rollback_err == nil then
    return err
  end
  return ('%s; rollback errors: %s'):format(tostring(err), tostring(rollback_err))
end

local function refresh_or_rollback(instance, name, rollback)
  local ok, err = xpcall(function()
    refresh(instance, name)
  end, debug.traceback)
  if ok then
    return true, nil
  end

  local rollback_ok, rollback_err = xpcall(rollback, debug.traceback)
  if not rollback_ok then
    error(append_rollback_error(err, rollback_err), 0)
  end
  local restore_refresh_ok, restore_refresh_err = xpcall(function()
    refresh(instance, name)
  end, debug.traceback)
  if not restore_refresh_ok then
    error(append_rollback_error(err, restore_refresh_err), 0)
  end
  error(err, 0)
end

function M.draft_entry(name)
  return copy_entry(engine.get(assert_name(name)), 'draft session entry')
end

function M.persisted_entry(name)
  return copy_entry(engine.get_persisted(assert_name(name)), 'persisted session entry')
end

function M.draft_group(name)
  return engine.get_draft_group(assert_name(name))
end

function M.persisted_group(name)
  return engine.get_persisted_group(assert_name(name))
end

function M.display_group(name)
  return M.draft_group(name)
end

function M.display_value(name, key, fallback)
  key = assert_key(key)
  local entry = M.draft_entry(name)
  if entry[key] ~= nil then
    return entry[key]
  end
  return fallback
end

function M.field_value(name, key)
  key = assert_key(key)
  return M.draft_entry(name)[key]
end

function M.dynamic_value(name, key)
  key = assert_key(key)
  local entry = M.draft_entry(name)
  local dynamic = dynamic_model.normalize_dynamic(entry.dynamic)
  if entry.dynamic ~= nil and not dynamic then
    error('session entry has invalid dynamic override', 2)
  end
  return dynamic and dynamic[key] or nil
end

function M.is_dirty(name)
  return not same_entry(M.draft_entry(name), M.persisted_entry(name)) or M.draft_group(name) ~= M.persisted_group(name)
end

function M.set_color(instance, name, key, value)
  name = assert_name(name)
  key = assert_key(key)
  instance = assert_refresh_target(instance)
  local previous = engine.get(name)[key]
  local ok, err = engine.set_color(name, key, value)
  if not ok then
    return false, err
  end

  return refresh_or_rollback(instance, name, function()
    local restore_ok, restore_err = engine.set_color(name, key, previous)
    assert_engine_result(restore_ok, restore_err, 'failed to restore color after refresh failure')
  end)
end

function M.set_dynamic(instance, name, key, dynamic)
  name = assert_name(name)
  key = assert_key(key)
  instance = assert_refresh_target(instance)
  local previous_entry = engine.get(name)
  local previous_dynamic = type(previous_entry.dynamic) == 'table' and previous_entry.dynamic[key] or nil
  local ok, err = engine.set_dynamic(name, key, dynamic)
  if not ok then
    return false, err
  end

  return refresh_or_rollback(instance, name, function()
    local restore_ok, restore_err = engine.set_dynamic(name, key, previous_dynamic)
    assert_engine_result(restore_ok, restore_err, 'failed to restore dynamic color after refresh failure')
  end)
end

function M.set_style(instance, name, key, value)
  name = assert_name(name)
  key = assert_key(key)
  instance = assert_refresh_target(instance)
  local previous = engine.get(name)[key]
  local ok, err = engine.set_style(name, key, value)
  if not ok then
    return false, err
  end

  return refresh_or_rollback(instance, name, function()
    local restore_ok, restore_err = engine.set_style(name, key, previous)
    assert_engine_result(restore_ok, restore_err, 'failed to restore style after refresh failure')
  end)
end

function M.set_group(instance, name, group_name)
  name = assert_name(name)
  instance = assert_refresh_target(instance)
  local previous = engine.get_draft_group(name)
  local ok, err = engine.set_group(name, group_name)
  if not ok then
    return false, err
  end

  return refresh_or_rollback(instance, name, function()
    if previous == nil then
      local restore_ok, restore_err = engine.apply_patch(name, { group = vim.NIL })
      assert_engine_result(restore_ok, restore_err, 'failed to clear group after refresh failure')
      return
    end
    local restore_ok, restore_err = engine.set_group(name, previous)
    assert_engine_result(restore_ok, restore_err, 'failed to restore group after refresh failure')
  end)
end

function M.set_blend(instance, name, value)
  name = assert_name(name)
  instance = assert_refresh_target(instance)
  local previous = engine.get(name).blend
  local ok, err = engine.set_blend(name, value)
  if not ok then
    return false, err
  end

  return refresh_or_rollback(instance, name, function()
    local restore_ok, restore_err = engine.set_blend(name, previous)
    assert_engine_result(restore_ok, restore_err, 'failed to restore blend after refresh failure')
  end)
end

function M.save(instance, name)
  name = assert_name(name)
  instance = assert_refresh_target(instance)
  local ok, err = engine.save()
  if not ok then
    return false, err
  end
  local refresh_ok, refresh_err = xpcall(function()
    refresh(instance, name)
  end, debug.traceback)
  if not refresh_ok then
    return false, refresh_err
  end
  return true, nil
end

function M.discard(instance, name)
  name = assert_name(name)
  instance = assert_refresh_target(instance)
  local previous_entry = engine.get(name)
  local previous_group = engine.get_draft_group(name)
  engine.restore_persisted(name)
  return refresh_or_rollback(instance, name, function()
    restore_draft(name, previous_entry, previous_group)
  end)
end

function M.known_groups()
  return engine.known_groups()
end

function M.file_path(name)
  return engine.file_path(assert_name(name))
end

return M
