local M = {}

local color = require('hlcraft.core.color')
local dynamic_model = require('hlcraft.dynamic.model')
local highlights = require('hlcraft.core.highlights')
local applier = require('hlcraft.engine.applier')
local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local data = store.data

local patch_key_set = {
  group = true,
  blend = true,
  dynamic = true,
}

for _, key in ipairs(store.color_keys) do
  patch_key_set[key] = true
end
for _, key in ipairs(store.style_keys) do
  patch_key_set[key] = true
end

local function is_unset(value)
  return value == nil or value == vim.NIL or (type(value) == 'string' and vim.trim(value) == '')
end

local function restore(name, entry, group)
  data.draft[name] = snapshot.deepcopy(entry)
  data.draft_groups[name] = group
  snapshot.rebuild_active()
  applier.apply_group(name)
end

local function normalize_blend(value)
  if is_unset(value) then
    return nil, nil
  end

  local number_value = tonumber(value)
  if number_value == nil then
    return nil, 'Blend override must be a number or empty'
  end

  if number_value < 0 or number_value > 100 then
    return nil, 'Blend override must be between 0 and 100'
  end

  return math.floor(number_value), nil
end

local function apply_color_patch(entry, key, value)
  local normalized, err
  if is_unset(value) then
    normalized = nil
  else
    normalized, err = color.normalize(value)
    if err then
      return nil, err
    end
  end

  entry[key] = normalized
  return true, nil
end

local function apply_style_patch(entry, key, value)
  if value == vim.NIL then
    entry[key] = nil
    return true, nil
  end

  if value ~= nil and type(value) ~= 'boolean' then
    return nil, ('Style override %s must be boolean or nil'):format(key)
  end

  entry[key] = value
  return true, nil
end

local function apply_dynamic_patch(entry, key, value)
  entry.dynamic = type(entry.dynamic) == 'table' and entry.dynamic or {}

  if value == nil or value == vim.NIL then
    entry.dynamic[key] = nil
    return true, nil
  end

  local normalized = dynamic_model.normalize_channel(value)
  if not normalized then
    return nil, ('Invalid dynamic spec for %s'):format(key)
  end

  entry.dynamic[key] = normalized
  return true, nil
end

local function patch_changes_entry(patch)
  if patch.blend ~= nil then
    return true
  end

  for _, key in ipairs(store.color_keys) do
    if patch[key] ~= nil then
      return true
    end
  end
  for _, key in ipairs(store.style_keys) do
    if patch[key] ~= nil then
      return true
    end
  end

  return type(patch.dynamic) == 'table'
end

local function validate_patch(patch)
  if type(patch) ~= 'table' then
    return false, 'Patch must be a table'
  end

  for key, _ in pairs(patch) do
    if not patch_key_set[key] then
      return false, ('Unsupported override key: %s'):format(tostring(key))
    end
  end

  if patch.dynamic ~= nil and type(patch.dynamic) ~= 'table' then
    return false, 'dynamic patch must be a table'
  end

  if patch.dynamic ~= nil then
    for key, _ in pairs(patch.dynamic) do
      if not dynamic_model.channel_set[key] then
        return false, ('Unsupported dynamic key: %s'):format(tostring(key))
      end
    end
  end

  return true, nil
end

--- Atomically mutate one draft highlight entry.
--- @param name string Highlight group name
--- @param patch table
--- @return boolean ok
--- @return string|nil err
function M.apply_patch(name, patch)
  local valid, validation_err = validate_patch(patch)
  if not valid then
    return false, validation_err
  end

  local previous_entry = snapshot.deepcopy(data.draft[name])
  local previous_group = data.draft_groups[name]
  local entry = snapshot.deepcopy(data.draft[name] or {})

  local function fail(err)
    restore(name, previous_entry, previous_group)
    return false, err
  end

  for _, key in ipairs(store.color_keys) do
    if patch[key] ~= nil then
      local ok, err = apply_color_patch(entry, key, patch[key])
      if not ok then
        return fail(err)
      end
    end
  end

  for _, key in ipairs(store.style_keys) do
    if patch[key] ~= nil then
      local ok, err = apply_style_patch(entry, key, patch[key])
      if not ok then
        return fail(err)
      end
    end
  end

  if patch.blend ~= nil then
    local normalized, err = normalize_blend(patch.blend)
    if err then
      return fail(err)
    end
    entry.blend = normalized
  end

  if type(patch.dynamic) == 'table' then
    for _, key in ipairs(dynamic_model.channels) do
      if patch.dynamic[key] ~= nil then
        local ok, err = apply_dynamic_patch(entry, key, patch.dynamic[key])
        if not ok then
          return fail(err)
        end
      end
    end
  end

  local compacted_entry = snapshot.compact_entry(entry)
  if patch.group ~= nil and is_unset(patch.group) and compacted_entry ~= nil then
    return fail('Group name is required for non-empty override')
  end

  if patch.group ~= nil then
    if is_unset(patch.group) then
      data.draft_groups[name] = nil
    else
      data.draft_groups[name] = vim.trim(tostring(patch.group))
      data.draft[name] = entry
    end
  elseif patch_changes_entry(patch) then
    snapshot.ensure_draft_group(name)
  end

  if patch_changes_entry(patch) then
    data.draft[name] = compacted_entry
    if data.draft[name] == nil then
      data.draft_groups[name] = nil
    end
  elseif patch.group ~= nil and data.draft[name] == nil and data.draft_groups[name] ~= nil then
    data.draft[name] = entry
  end

  snapshot.rebuild_active()
  applier.apply_group(name)
  return true, nil
end

--- Toggle one boolean style override against the current live highlight.
--- @param name string
--- @param key string
--- @return boolean ok
--- @return boolean|nil value
--- @return string|nil err
function M.toggle_style(name, key)
  local current = highlights.get_group(name)
  if not current then
    return false, nil, ('Unknown highlight group: %s'):format(name)
  end

  local active = data.active[name] and data.active[name][key]
  local next_value = active
  if next_value == nil then
    next_value = not current[key]
  else
    next_value = not next_value
  end

  local ok, err = M.apply_patch(name, { [key] = next_value })
  return ok, ok and next_value or nil, err
end

return M
