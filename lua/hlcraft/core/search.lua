--- @type table
local M = {}

local highlights = require('hlcraft.core.highlights')
local color = require('hlcraft.core.color')
local config = require('hlcraft.config')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')

local function is_none_query(value)
  return type(value) == 'string' and value:upper() == 'NONE'
end

local function include_sp()
  return config.config.include_sp_in_color_search == true
end

local function sort_by_name(results)
  table.sort(results, function(a, b)
    return tables.compare_names(a.name, b.name)
  end)
  return results
end

local function sort_by_distance(results)
  table.sort(results, function(a, b)
    if a.distance == b.distance then
      return tables.compare_names(a.name, b.name)
    end
    return a.distance < b.distance
  end)
  return results
end

local function with_distance(group, distance)
  local entry = vim.deepcopy(group)
  entry.distance = distance
  return entry
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

local function name_query(keyword)
  if keyword == nil or keyword == '' then
    return nil
  end
  if type(keyword) ~= 'string' then
    error('Name search query must be a string or nil', 3)
  end
  return keyword
end

--- Search highlight groups by keyword in name (case-insensitive substring match)
--- @param keyword string|nil The search keyword
--- @return table[] Array of matching highlight groups, sorted alphabetically by name
function M.by_name(keyword)
  keyword = name_query(keyword)
  if not keyword then
    return {}
  end

  local all = highlights.get_all()
  local results = {}
  local lower_keyword = keyword:lower()

  for _, group in ipairs(all) do
    if group.name:lower():find(lower_keyword, 1, true) then
      results[#results + 1] = vim.deepcopy(group)
    end
  end

  return sort_by_name(results)
end

local function none_matches(group)
  local matches = group.resolved_fg == 'NONE' or group.resolved_bg == 'NONE'
  return include_sp() and (matches or group.sp == 'NONE') or matches
end

local function by_none_color()
  local results = {}
  for _, group in ipairs(highlights.get_all()) do
    if none_matches(group) then
      results[#results + 1] = with_distance(group, 0)
    end
  end
  return sort_by_name(results)
end

local function nearest_distance(group, hex, max_dist)
  local distances = {
    color_distance(group.resolved_fg, hex),
    color_distance(group.resolved_bg, hex),
  }
  if include_sp() then
    distances[#distances + 1] = color_distance(group.sp, hex)
  end

  local best = nil
  for _, distance in ipairs(distances) do
    if distance and distance <= max_dist and (not best or distance < best) then
      best = distance
    end
  end
  return best
end

local function color_threshold(value)
  if value == nil then
    return config.config.threshold
  end
  if type(value) ~= 'number' or not numbers.is_finite(value) then
    error('Color search threshold must be a finite number', 3)
  end
  if value < 0 then
    error('Color search threshold must be >= 0', 3)
  end
  return value
end

local function color_query(hex)
  if hex == nil or hex == '' then
    return nil
  end
  if type(hex) ~= 'string' then
    error('Color search query must be a string or nil', 3)
  end
  if is_none_query(hex) then
    return hex
  end
  if not color.hex_to_int(hex) then
    error('Color search query must be #RRGGBB or NONE', 3)
  end
  return hex
end

--- Search highlight groups by color similarity (RGB Euclidean distance)
--- @param hex string|nil Target color in #RRGGBB format
--- @param threshold number|nil Optional distance threshold override (uses config default if nil)
--- @return table[] Array of matching highlight groups with distance field, sorted by distance ascending
function M.by_color(hex, threshold)
  hex = color_query(hex)
  if not hex then
    return {}
  end

  if is_none_query(hex) then
    return by_none_color()
  end

  local max_dist = color_threshold(threshold)
  local all = highlights.get_all()
  local results = {}

  for _, group in ipairs(all) do
    local best_dist = nearest_distance(group, hex, max_dist)
    if best_dist then
      results[#results + 1] = with_distance(group, best_dist)
    end
  end

  return sort_by_distance(results)
end

return M
