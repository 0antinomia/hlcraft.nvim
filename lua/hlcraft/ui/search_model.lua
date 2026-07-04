local M = {}

local color = require('hlcraft.core.color')
local search = require('hlcraft.core.search')

local function normalize_query(query)
  return type(query) == 'string' and query or ''
end

function M.empty_message(name_query, color_query)
  if name_query == '' and color_query == '' then
    return 'Use Name and Color search together to narrow highlight groups'
  end
  if name_query ~= '' and color_query ~= '' then
    return 'No highlight groups match both the name and color filters'
  end
  if color_query ~= '' then
    return 'No highlight groups match this color filter'
  end
  return 'No highlight groups match this name filter'
end

function M.valid_color_query(query)
  return type(query) == 'string' and (query:upper() == 'NONE' or color.hex_to_int(query) ~= nil)
end

function M.intersect(name_results, color_results)
  local color_index = {}
  local results = {}

  for _, item in ipairs(color_results or {}) do
    color_index[item.name] = item
  end

  for _, item in ipairs(name_results or {}) do
    local color_match = color_index[item.name]
    if color_match then
      local entry = vim.deepcopy(item)
      entry.distance = color_match.distance
      results[#results + 1] = entry
    end
  end

  table.sort(results, function(a, b)
    if a.distance and b.distance and a.distance ~= b.distance then
      return a.distance < b.distance
    end
    return a.name:lower() < b.name:lower()
  end)

  return results
end

function M.results(name_query, color_query, provider)
  provider = provider or search
  name_query = normalize_query(name_query)
  color_query = normalize_query(color_query)

  if name_query ~= '' and color_query ~= '' then
    if M.valid_color_query(color_query) then
      return M.intersect(provider.by_name(name_query), provider.by_color(color_query))
    end
    return {}
  end

  if name_query ~= '' then
    return provider.by_name(name_query)
  end

  if color_query ~= '' then
    if M.valid_color_query(color_query) then
      return provider.by_color(color_query)
    end
    return {}
  end

  return {}
end

return M
