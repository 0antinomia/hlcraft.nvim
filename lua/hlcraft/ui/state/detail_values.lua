local overrides = require('hlcraft.overrides')

local M = {}

local color_keys = { 'fg', 'bg', 'sp' }
local style_keys = {
  'bold',
  'italic',
  'underline',
  'undercurl',
  'strikethrough',
  'underdouble',
  'underdotted',
  'underdashed',
}
local blend_keys = { 'blend' }

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

local function has_entry(entry)
  return entry ~= nil and next(entry) ~= nil
end

local function is_blank(value)
  return type(value) == 'string' and vim.trim(value) == ''
end

local function is_unset(value)
  return value == vim.NIL or is_blank(value)
end

local function refresh(instance, name)
  if instance then
    get_results_state().refresh(instance, name, true)
  end
end

local function apply_entry(name, entry, group, keep_group)
  overrides.clear(name)
  if group ~= nil and (has_entry(entry) or keep_group) then
    local ok, err = overrides.set_group(name, group)
    if not ok then
      return false, err
    end
  end

  for _, key in ipairs(color_keys) do
    if entry[key] ~= nil then
      local ok, err = overrides.set_color(name, key, entry[key])
      if not ok then
        return false, err
      end
    end
  end
  for _, key in ipairs(style_keys) do
    if entry[key] ~= nil then
      local ok, err = overrides.set_style(name, key, entry[key])
      if not ok then
        return false, err
      end
    end
  end
  for _, key in ipairs(blend_keys) do
    if entry[key] ~= nil then
      local ok, err = overrides.set_blend(name, entry[key])
      if not ok then
        return false, err
      end
    end
  end

  return true, nil
end

function M.runtime_entry(name)
  return shallow_copy(overrides.get(name))
end

function M.persisted_entry(name)
  return shallow_copy(overrides.get_persisted(name))
end

function M.runtime_group(name)
  return overrides.get_runtime_group(name)
end

function M.persisted_group(name)
  return overrides.get_persisted_group(name)
end

function M.display_group(name)
  return M.runtime_group(name)
end

function M.display_value(name, key, fallback)
  local entry = M.runtime_entry(name)
  if entry[key] ~= nil then
    return entry[key]
  end
  return fallback
end

function M.is_dirty(name)
  return not same_entry(M.runtime_entry(name), M.persisted_entry(name))
    or M.runtime_group(name) ~= M.persisted_group(name)
end

function M.apply_runtime(instance, name, patch)
  patch = patch or {}
  local previous_entry = M.runtime_entry(name)
  local previous_group = M.runtime_group(name)
  local previous_had_state = has_entry(previous_entry) or previous_group ~= M.persisted_group(name)
  local next_entry = M.runtime_entry(name)
  local group = patch.group ~= nil and patch.group or M.runtime_group(name)

  for _, key in ipairs(color_keys) do
    if patch[key] ~= nil then
      if is_unset(patch[key]) then
        next_entry[key] = nil
      else
        next_entry[key] = patch[key]
      end
    end
  end
  for _, key in ipairs(style_keys) do
    if patch[key] ~= nil then
      if patch[key] == vim.NIL then
        next_entry[key] = nil
      else
        next_entry[key] = patch[key]
      end
    end
  end
  for _, key in ipairs(blend_keys) do
    if patch[key] ~= nil then
      if is_unset(patch[key]) then
        next_entry[key] = nil
      else
        next_entry[key] = patch[key]
      end
    end
  end

  local keep_group = patch.group ~= nil or group ~= M.persisted_group(name)
  local ok, err = apply_entry(name, next_entry, group, keep_group)
  if not ok then
    apply_entry(name, previous_entry, previous_group, previous_had_state)
    return false, err
  end

  refresh(instance, name)
  return true, nil
end

function M.save(instance, name)
  local ok, err = overrides.save()
  if not ok then
    return false, err
  end
  refresh(instance, name)
  return true, nil
end

function M.discard(instance, name)
  overrides.restore_persisted(name)
  refresh(instance, name)
  return true, nil
end

return M
