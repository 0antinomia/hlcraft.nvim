local highlights = require('hlcraft.core.highlights')
local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local M = {}

function M.normalized_set_hl_spec(name)
  local group = highlights.get_group(name)
  if not group then
    return {}
  end

  return {
    fg = group.resolved_fg ~= 'NONE' and group.resolved_fg or 'NONE',
    bg = group.resolved_bg ~= 'NONE' and group.resolved_bg or 'NONE',
    sp = group.sp ~= 'NONE' and group.sp or 'NONE',
    bold = group.bold or nil,
    italic = group.italic or nil,
    underline = group.underline or nil,
    undercurl = group.undercurl or nil,
    strikethrough = group.strikethrough or nil,
    underdouble = group.underdouble or nil,
    underdotted = group.underdotted or nil,
    underdashed = group.underdashed or nil,
    blend = group.blend,
  }
end

function M.group_exists(name)
  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = name, create = false })
  return ok and spec and not vim.tbl_isempty(spec)
end

function M.capture(state, name)
  if state.base_specs[name] ~= nil then
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
  local base = state.base_specs[name]
  if not base then
    return
  end

  vim.api.nvim_set_hl(0, name, snapshot.deepcopy(base))
end

function M.merged(state, name)
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
