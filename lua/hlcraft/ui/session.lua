local dynamic_model = require('hlcraft.dynamic.model')
local engine = require('hlcraft.engine.service')

local M = {}

local function shallow_copy(value)
  local copy = {}
  for key, item in pairs(value or {}) do
    copy[key] = item
  end
  return copy
end

local function same_entry(left, right)
  return vim.deep_equal(left or {}, right or {})
end

local function refresh(instance, name)
  if instance and instance.state and type(instance.state.results) == 'table' then
    require('hlcraft.ui.scene.detail').refresh(instance, name, true)
  elseif instance and instance.rerender then
    instance:rerender()
  end
end

function M.draft_entry(name)
  return shallow_copy(engine.get(name))
end

function M.persisted_entry(name)
  return shallow_copy(engine.get_persisted(name))
end

function M.draft_group(name)
  return engine.get_draft_group(name)
end

function M.persisted_group(name)
  return engine.get_persisted_group(name)
end

function M.display_group(name)
  return M.draft_group(name)
end

function M.display_value(name, key, fallback)
  local entry = M.draft_entry(name)
  if entry[key] ~= nil then
    return entry[key]
  end
  return fallback
end

function M.field_value(name, key)
  return M.draft_entry(name)[key]
end

function M.dynamic_value(name, key)
  local entry = M.draft_entry(name)
  local dynamic = dynamic_model.normalize_dynamic(entry.dynamic)
  return dynamic and dynamic[key] or nil
end

function M.display_color_value(name, key, fallback)
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
  local ok, err = engine.set_color(name, key, value)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.set_dynamic(instance, name, key, dynamic)
  local ok, err = engine.set_dynamic(name, key, dynamic)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.set_style(instance, name, key, value)
  local ok, err = engine.set_style(name, key, value)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.set_group(instance, name, group_name)
  local ok, err = engine.set_group(name, group_name)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.set_blend(instance, name, value)
  local ok, err = engine.set_blend(name, value)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.save(instance, name)
  local ok, err = engine.save()
  if not ok then
    return false, err
  end
  refresh(instance, name)
  return true, nil
end

function M.discard(instance, name)
  engine.restore_persisted(name)
  refresh(instance, name)
  return true, nil
end

function M.known_groups()
  return engine.known_groups()
end

function M.file_path(name)
  return engine.file_path(name)
end

return M
