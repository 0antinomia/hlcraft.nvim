local dynamic_model = require('hlcraft.dynamic.model')
local engine = require('hlcraft.engine.service')

local M = {}

local function get_results_state()
  return require('hlcraft.ui.state.results')
end

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
  if instance then
    get_results_state().refresh(instance, name, true)
  end
end

function M.draft_entry(name)
  return shallow_copy(engine.get(name))
end

M.runtime_entry = M.draft_entry

function M.persisted_entry(name)
  return shallow_copy(engine.get_persisted(name))
end

function M.draft_group(name)
  return engine.get_draft_group(name)
end

M.runtime_group = M.draft_group

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

function M.dynamic_value(name, key)
  local entry = M.draft_entry(name)
  local dynamic = dynamic_model.normalize_dynamic(entry.dynamic)
  return dynamic and dynamic[key] or nil
end

function M.display_color_value(name, key, fallback)
  local dynamic = M.dynamic_value(name, key)
  if dynamic then
    return ('dynamic:%s %dms'):format(dynamic.mode, dynamic.speed)
  end
  return M.display_value(name, key, fallback)
end

function M.is_dirty(name)
  return not same_entry(M.draft_entry(name), M.persisted_entry(name)) or M.draft_group(name) ~= M.persisted_group(name)
end

function M.apply_patch(instance, name, patch)
  local ok, err = engine.apply_patch(name, patch)
  if not ok then
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

M.apply_runtime = M.apply_patch

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

return M
