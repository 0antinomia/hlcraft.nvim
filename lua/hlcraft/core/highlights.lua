--- @type table
local M = {}

local fields = require('hlcraft.core.fields')
local highlight_entry = require('hlcraft.core.highlight_entry')

--- Module-level cache for highlight group enumeration.
--- Invalidated on ColorScheme events.
local cache = {
  groups = nil, -- table[]|nil cached result of get_all()
  raw_map = nil, -- table|nil mapping name -> raw attrs from nvim_get_hl(0, {})
}

--- Resolve link chain using the bulk result map instead of per-name API calls.
--- Same algorithm as resolve_link_chain but reads from raw_map.
--- @param name string Starting group name
--- @param raw_map table Mapping name -> raw hl attrs from bulk call
--- @return string[] chain Chain of group names from start to terminal
local function resolve_chain_from_map(name, raw_map)
  local chain = { name }
  local visited = { [name] = true }
  local current = name

  for _ = 1, 20 do
    local attrs = raw_map[current]
    if not attrs or not attrs.link then
      break
    end

    local target = attrs.link
    if visited[target] then
      chain[#chain + 1] = target .. ' (circular)'
      break
    end

    visited[target] = true
    chain[#chain + 1] = target
    current = target
  end

  return chain
end

--- Build a complete highlight entry from bulk data.
--- Resolves link chains from the bulk result with per-name fallback for missing targets.
--- @param name string Highlight group name
--- @param attrs table Raw attributes from nvim_get_hl bulk call
--- @param all_hls table Full bulk result map (name -> attrs)
--- @return table Highlight group entry
local function build_entry_from_raw(name, attrs, all_hls)
  return highlight_entry.from_attrs(name, attrs, {
    resolve_chain = function(group_name)
      return resolve_chain_from_map(group_name, all_hls)
    end,
    resolve_attrs = function(group_name)
      return all_hls[group_name] or vim.api.nvim_get_hl(0, { name = group_name, create = false })
    end,
  })
end

--- Resolve the full link chain for a highlight group (per-name API calls).
--- Used by the engine for single-group lookups.
--- @param name string Starting group name
--- @return string[] chain Chain of group names from start to terminal
function M.resolve_link_chain(name)
  local chain = { name }
  local visited = { [name] = true }
  local current = name

  for _ = 1, 20 do
    local hl = vim.api.nvim_get_hl(0, { name = current, create = false })
    if not hl or not hl.link then
      break
    end

    local target = hl.link
    if visited[target] then
      chain[#chain + 1] = target .. ' (circular)'
      break
    end

    visited[target] = true
    chain[#chain + 1] = target
    current = target
  end

  return chain
end

--- Get a single highlight group with resolved attributes (per-name API call).
--- Used by the engine for single-group lookups. Does NOT use cache.
--- @param name string Highlight group name
--- @return table|nil Group data with name, attributes, link_chain, resolved colors
function M.get_group(name)
  local hl = vim.api.nvim_get_hl(0, { name = name, create = false })
  if not hl or vim.tbl_isempty(hl) then
    return nil
  end

  return highlight_entry.from_attrs(name, hl, {
    resolve_chain = M.resolve_link_chain,
    resolve_attrs = function(group_name)
      return vim.api.nvim_get_hl(0, { name = group_name, create = false })
    end,
  })
end

--- Get all highlight groups as a flat list with normalized attributes.
--- Uses single bulk nvim_get_hl(0, {}) call with module-level cache.
--- Callers (search.lua) already deepcopy before mutating, so no copy needed here.
--- @return table[] Array of highlight group data
function M.get_all()
  if cache.groups then
    return cache.groups
  end

  local all_hls = vim.api.nvim_get_hl(0, {})
  cache.raw_map = all_hls
  local result = {}

  for name, attrs in pairs(all_hls) do
    if type(name) == 'string' and not vim.tbl_isempty(attrs) then
      local entry = build_entry_from_raw(name, attrs, all_hls)
      result[#result + 1] = entry
    end
  end

  cache.groups = result
  return result
end

--- Invalidate the highlight cache. Called on ColorScheme events.
--- @return nil
function M.invalidate_cache()
  cache.groups = nil
  cache.raw_map = nil
end

--- Format boolean style attributes of a highlight group as a comma-separated string.
--- @param result table Highlight group data with boolean style keys
--- @return string Comma-separated attribute names, or '-' if none are set
function M.bool_attrs(result)
  local attrs = {}
  for _, attr in ipairs(fields.style_keys) do
    if result[attr] then
      attrs[#attrs + 1] = attr
    end
  end
  return #attrs > 0 and table.concat(attrs, ', ') or '-'
end

-- Register ColorScheme autocmd for cache invalidation.
local cache_augroup = vim.api.nvim_create_augroup('hlcraft-cache', { clear = true })
vim.api.nvim_create_autocmd('ColorScheme', {
  group = cache_augroup,
  callback = function()
    M.invalidate_cache()
  end,
  desc = 'hlcraft: invalidate highlight cache on colorscheme change',
})

return M
