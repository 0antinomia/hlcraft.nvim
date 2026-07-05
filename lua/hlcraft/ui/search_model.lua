local M = {}

local color = require('hlcraft.core.color')
local search = require('hlcraft.core.search')
local tables = require('hlcraft.core.tables')

local function assert_string(value, label)
  if type(value) ~= 'string' then
    error(('%s must be a string'):format(label), 3)
  end
  return value
end

local function assert_results(value, label)
  value = tables.assert_sequence(value, label, 3)
  for index, item in ipairs(value) do
    if type(item) ~= 'table' then
      error(('%s[%d] must be a table'):format(label, index), 3)
    end
    if type(item.name) ~= 'string' or item.name == '' then
      error(('%s[%d].name must be a non-empty string'):format(label, index), 3)
    end
  end
  return value
end

local function assert_provider(provider)
  if provider == nil then
    provider = search
  end
  if type(provider) ~= 'table' then
    error('search provider must be a table', 3)
  end
  if type(provider.by_name) ~= 'function' or type(provider.by_color) ~= 'function' then
    error('search provider must define by_name and by_color', 3)
  end
  return provider
end

local function normalized_color_query(query)
  if type(query) ~= 'string' then
    return nil
  end
  query = vim.trim(query)
  if query:upper() == 'NONE' or color.hex_to_int(query) ~= nil then
    return query
  end
  return nil
end

function M.empty_message(name_query, color_query)
  name_query = assert_string(name_query, 'name query')
  color_query = assert_string(color_query, 'color query')
  color_query = vim.trim(color_query)
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
  return normalized_color_query(query) ~= nil
end

function M.intersect(name_results, color_results)
  name_results = assert_results(name_results, 'name search results')
  color_results = assert_results(color_results, 'color search results')
  local color_index = {}
  local results = {}

  for _, item in ipairs(color_results) do
    color_index[item.name] = item
  end

  for _, item in ipairs(name_results) do
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
    return tables.compare_names(a.name, b.name)
  end)

  return results
end

function M.results(name_query, color_query, provider)
  name_query = assert_string(name_query, 'name query')
  color_query = assert_string(color_query, 'color query')
  provider = assert_provider(provider)
  color_query = vim.trim(color_query)
  local normalized_color = normalized_color_query(color_query)

  if name_query ~= '' and color_query ~= '' then
    if normalized_color then
      return M.intersect(
        assert_results(provider.by_name(name_query), 'name search results'),
        assert_results(provider.by_color(normalized_color), 'color search results')
      )
    end
    return {}
  end

  if name_query ~= '' then
    return assert_results(provider.by_name(name_query), 'name search results')
  end

  if color_query ~= '' then
    if normalized_color then
      return assert_results(provider.by_color(normalized_color), 'color search results')
    end
    return {}
  end

  return {}
end

return M
