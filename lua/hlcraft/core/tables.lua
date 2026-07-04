local M = {}

local function compare_keys(left, right)
  return tostring(left) < tostring(right)
end

function M.is_sequence(value)
  if type(value) ~= 'table' then
    return false
  end

  local count = 0
  local max_index = 0
  for key in pairs(value) do
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
      return false
    end
    count = count + 1
    max_index = math.max(max_index, key)
  end

  return count == max_index
end

function M.sorted_keys(value, compare)
  if type(value) ~= 'table' then
    return {}
  end

  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, compare or compare_keys)
  return keys
end

return M
