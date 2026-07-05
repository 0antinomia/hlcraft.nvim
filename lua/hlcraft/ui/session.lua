local dynamic_model = require('hlcraft.dynamic.model')
local engine = require('hlcraft.engine.service')
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

function M.display_color_value(name, key, fallback)
  key = assert_key(key)
  local dynamic = M.dynamic_value(name, key)
  if dynamic then
    return ('dynamic:%s %dms'):format(dynamic.preset or 'custom', dynamic.duration)
  end
  return M.display_value(name, key, fallback)
end

function M.is_dirty(name)
  return not same_entry(M.draft_entry(name), M.persisted_entry(name)) or M.draft_group(name) ~= M.persisted_group(name)
end

function M.set_color(instance, name, key, value)
  name = assert_name(name)
  key = assert_key(key)
  instance = assert_refresh_target(instance)
  local ok, err = engine.set_color(name, key, value)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.set_dynamic(instance, name, key, dynamic)
  name = assert_name(name)
  key = assert_key(key)
  instance = assert_refresh_target(instance)
  local ok, err = engine.set_dynamic(name, key, dynamic)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.set_style(instance, name, key, value)
  name = assert_name(name)
  key = assert_key(key)
  instance = assert_refresh_target(instance)
  local ok, err = engine.set_style(name, key, value)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.set_group(instance, name, group_name)
  name = assert_name(name)
  instance = assert_refresh_target(instance)
  local ok, err = engine.set_group(name, group_name)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.set_blend(instance, name, value)
  name = assert_name(name)
  instance = assert_refresh_target(instance)
  local ok, err = engine.set_blend(name, value)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.save(instance, name)
  name = assert_name(name)
  instance = assert_refresh_target(instance)
  local ok, err = engine.save()
  if not ok then
    return false, err
  end
  refresh(instance, name)
  return true, nil
end

function M.discard(instance, name)
  name = assert_name(name)
  instance = assert_refresh_target(instance)
  engine.restore_persisted(name)
  refresh(instance, name)
  return true, nil
end

function M.known_groups()
  return engine.known_groups()
end

function M.file_path(name)
  return engine.file_path(assert_name(name))
end

return M
