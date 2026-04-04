--- @type table
local M = {}

local highlights = require('hlcraft.highlights')
local color = require('hlcraft.color')
local config = require('hlcraft.config')

local function is_none_query(value)
  return type(value) == 'string' and value:upper() == 'NONE'
end

local function include_sp()
  return config.config.include_sp_in_color_search == true
end

--- Compute RGB Euclidean distance between two hex color strings
--- @param hex1 string First color in #RRGGBB format
--- @param hex2 string Second color in #RRGGBB format
--- @return number|nil distance Euclidean distance, or nil if either color is invalid
local function color_distance(hex1, hex2)
  local int1 = color.hex_to_int(hex1)
  local int2 = color.hex_to_int(hex2)
  if not int1 or not int2 then
    return nil
  end

  local r1, g1, b1 = color.int_to_rgb(int1)
  local r2, g2, b2 = color.int_to_rgb(int2)

  local dr = r1 - r2
  local dg = g1 - g2
  local db = b1 - b2

  return math.sqrt(dr * dr + dg * dg + db * db)
end

--- Search highlight groups by keyword in name (case-insensitive substring match)
--- @param keyword string|nil The search keyword
--- @return table[] Array of matching highlight groups, sorted alphabetically by name
function M.by_name(keyword)
  if not keyword or keyword == '' then
    return {}
  end

  local all = highlights.get_all()
  local results = {}
  local lower_keyword = keyword:lower()

  for _, group in ipairs(all) do
    if group.name:lower():find(lower_keyword, 1, true) then
      results[#results + 1] = group
    end
  end

  table.sort(results, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  return results
end

--- Search highlight groups by color similarity (RGB Euclidean distance)
--- @param hex string|nil Target color in #RRGGBB format
--- @param threshold number|nil Optional distance threshold override (uses config default if nil)
--- @return table[] Array of matching highlight groups with distance field, sorted by distance ascending
function M.by_color(hex, threshold)
  if not hex then
    return {}
  end

  if is_none_query(hex) then
    local all = highlights.get_all()
    local results = {}

    for _, group in ipairs(all) do
      local matches_none = group.resolved_fg == 'NONE' or group.resolved_bg == 'NONE'
      if include_sp() then
        matches_none = matches_none or group.sp == 'NONE'
      end

      if matches_none then
        local entry = vim.deepcopy(group)
        entry.distance = 0
        results[#results + 1] = entry
      end
    end

    table.sort(results, function(a, b)
      return a.name:lower() < b.name:lower()
    end)

    return results
  end

  local target_int = color.hex_to_int(hex)
  if not target_int then
    vim.notify('Invalid color format: ' .. tostring(hex) .. '. Use #RRGGBB or NONE.', vim.log.levels.ERROR)
    return {}
  end

  local max_dist = threshold or config.config.threshold
  local all = highlights.get_all()
  local results = {}

  for _, group in ipairs(all) do
    local fg_dist = color_distance(group.resolved_fg, hex)
    local bg_dist = color_distance(group.resolved_bg, hex)
    local sp_dist = include_sp() and color_distance(group.sp, hex) or nil

    local best_dist = nil

    if fg_dist and fg_dist <= max_dist then
      best_dist = fg_dist
    end

    if bg_dist and bg_dist <= max_dist then
      if not best_dist or bg_dist < best_dist then
        best_dist = bg_dist
      end
    end

    if sp_dist and sp_dist <= max_dist then
      if not best_dist or sp_dist < best_dist then
        best_dist = sp_dist
      end
    end

    if best_dist then
      local entry = vim.deepcopy(group)
      entry.distance = best_dist
      results[#results + 1] = entry
    end
  end

  table.sort(results, function(a, b)
    return a.distance < b.distance
  end)

  return results
end

return M
