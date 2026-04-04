--- @type table
local M = {}

local color = require('hlcraft.color')

--- Module-level cache for highlight group enumeration (D-10)
--- Invalidated on ColorScheme events (D-11, D-13)
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

--- Build a complete highlight entry from bulk data (D-12).
--- Resolves link chains from the bulk result with per-name fallback for missing targets.
--- @param name string Highlight group name
--- @param attrs table Raw attributes from nvim_get_hl bulk call
--- @param all_hls table Full bulk result map (name -> attrs)
--- @return table Highlight group entry
local function build_entry_from_raw(name, attrs, all_hls)
  local entry = {
    name = name,
    fg = color.int_to_hex(attrs.fg),
    bg = color.int_to_hex(attrs.bg),
    sp = color.int_to_hex(attrs.sp),
    bold = attrs.bold or false,
    italic = attrs.italic or false,
    underline = attrs.underline or false,
    undercurl = attrs.undercurl or false,
    strikethrough = attrs.strikethrough or false,
    underdouble = attrs.underdouble or false,
    underdotted = attrs.underdotted or false,
    underdashed = attrs.underdashed or false,
    blend = attrs.blend,
    link_chain = {},
    resolved_fg = 'NONE',
    resolved_bg = 'NONE',
  }

  if attrs.link then
    entry.link_chain = resolve_chain_from_map(name, all_hls)
    local terminal = entry.link_chain[#entry.link_chain]
    if terminal then
      -- Strip " (circular)" suffix if present
      terminal = terminal:gsub(' %(circular%)$', '')
      local resolved = all_hls[terminal]
      if resolved then
        entry.resolved_fg = color.int_to_hex(resolved.fg)
        entry.resolved_bg = color.int_to_hex(resolved.bg)
      else
        -- Fallback: target not in bulk result (e.g. treesitter groups not yet loaded)
        local term_hl = vim.api.nvim_get_hl(0, { name = terminal, create = false })
        if term_hl then
          entry.resolved_fg = color.int_to_hex(term_hl.fg)
          entry.resolved_bg = color.int_to_hex(term_hl.bg)
        end
      end
    end
  else
    entry.resolved_fg = entry.fg
    entry.resolved_bg = entry.bg
  end

  return entry
end

--- Resolve the full link chain for a highlight group (per-name API calls).
--- Used by overrides.lua for single-group lookups.
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
--- Used by overrides.lua for single-group lookups. Does NOT use cache.
--- @param name string Highlight group name
--- @return table|nil Group data with name, attributes, link_chain, resolved colors
function M.get_group(name)
  local hl = vim.api.nvim_get_hl(0, { name = name, create = false })
  if not hl or vim.tbl_isempty(hl) then
    return nil
  end

  local entry = {
    name = name,
    fg = color.int_to_hex(hl.fg),
    bg = color.int_to_hex(hl.bg),
    sp = color.int_to_hex(hl.sp),
    bold = hl.bold or false,
    italic = hl.italic or false,
    underline = hl.underline or false,
    undercurl = hl.undercurl or false,
    strikethrough = hl.strikethrough or false,
    underdouble = hl.underdouble or false,
    underdotted = hl.underdotted or false,
    underdashed = hl.underdashed or false,
    blend = hl.blend,
    link_chain = {},
    resolved_fg = 'NONE',
    resolved_bg = 'NONE',
  }

  if hl.link then
    entry.link_chain = M.resolve_link_chain(name)
    local terminal = entry.link_chain[#entry.link_chain]
    if terminal then
      -- Strip " (circular)" suffix if present
      terminal = terminal:gsub(' %(circular%)$', '')
      local resolved = vim.api.nvim_get_hl(0, { name = terminal, create = false })
      if resolved then
        entry.resolved_fg = color.int_to_hex(resolved.fg)
        entry.resolved_bg = color.int_to_hex(resolved.bg)
      end
    end
  else
    entry.resolved_fg = entry.fg
    entry.resolved_bg = entry.bg
  end

  return entry
end

--- Get all highlight groups as a flat list with normalized attributes.
--- Uses single bulk nvim_get_hl(0, {}) call with module-level cache (D-10, D-12).
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

--- Invalidate the highlight cache. Called on ColorScheme events (D-13).
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
  for _, attr in ipairs({ 'bold', 'italic', 'underline', 'undercurl', 'strikethrough' }) do
    if result[attr] then
      attrs[#attrs + 1] = attr
    end
  end
  return #attrs > 0 and table.concat(attrs, ', ') or '-'
end

-- Register ColorScheme autocmd for cache invalidation (D-13)
local cache_augroup = vim.api.nvim_create_augroup('hlcraft-cache', { clear = true })
vim.api.nvim_create_autocmd('ColorScheme', {
  group = cache_augroup,
  callback = function()
    M.invalidate_cache()
  end,
  desc = 'hlcraft: invalidate highlight cache on colorscheme change',
})

return M
