local highlights = require('hlcraft.core.highlights')
local highlight_names = require('hlcraft.core.highlight_names')
local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local M = {}

local function assert_name(name)
  return highlight_names.assert(name, 'base spec highlight name', 3)
end

local function base_spec_state(state)
  if type(state) ~= 'table' or type(state.base_specs) ~= 'table' then
    error('base spec state must include base_specs table', 3)
  end
  return state
end

local function active_state(state)
  state = base_spec_state(state)
  if type(state.active) ~= 'table' then
    error('base spec state must include active table', 3)
  end
  return state
end

local function cached_base_spec(state, name)
  local spec = state.base_specs[name]
  if spec ~= nil and type(spec) ~= 'table' then
    error(('base spec %s must be a table'):format(name), 3)
  end
  return spec
end

function M.normalized_set_hl_spec(name)
  name = assert_name(name)
  local group = highlights.get_group(name)
  if not group then
    return {}
  end

  local spec = {
    fg = group.resolved_fg ~= 'NONE' and group.resolved_fg or 'NONE',
    bg = group.resolved_bg ~= 'NONE' and group.resolved_bg or 'NONE',
    sp = group.sp ~= 'NONE' and group.sp or 'NONE',
  }

  for _, key in ipairs(store.style_keys) do
    if group[key] then
      spec[key] = true
    end
  end
  for _, key in ipairs(store.numeric_keys) do
    spec[key] = group[key]
  end

  return spec
end

function M.group_exists(name)
  name = assert_name(name)
  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = name, create = false })
  return ok and spec and not vim.tbl_isempty(spec)
end

function M.capture(state, name)
  state = base_spec_state(state)
  name = assert_name(name)
  if cached_base_spec(state, name) ~= nil then
    return
  end

  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = name, create = false })
  if ok and spec and not vim.tbl_isempty(spec) then
    state.base_specs[name] = snapshot.deepcopy(spec)
    return
  end

  state.base_specs[name] = M.normalized_set_hl_spec(name)
end

function M.restore(state, name)
  state = base_spec_state(state)
  name = assert_name(name)
  local base = cached_base_spec(state, name)
  if base == nil then
    return
  end

  vim.api.nvim_set_hl(0, name, snapshot.deepcopy(base))
end

function M.merged(state, name)
  state = active_state(state)
  name = assert_name(name)
  M.capture(state, name)

  local spec = M.normalized_set_hl_spec(name)
  local override = state.active[name]
  if not override then
    return spec
  end

  for _, key in ipairs(store.override_keys) do
    if override[key] ~= nil then
      spec[key] = override[key]
    end
  end

  return spec
end

return M
