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

function M.assert_sequence(value, label, level)
  local error_level = level or 2
  if type(label) ~= 'string' or label == '' then
    error('sequence label must be a non-empty string', 2)
  end
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), error_level)
  end
  if not M.is_sequence(value) then
    error(('%s must be a sequence'):format(label), error_level)
  end
  return value
end

function M.sorted_keys(value, compare)
  if type(value) ~= 'table' then
    error('sorted_keys value must be a table', 2)
  end

  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, compare or compare_keys)
  return keys
end

function M.has_only_keys(value, allowed)
  if type(value) ~= 'table' or type(allowed) ~= 'table' then
    return false
  end

  for key in pairs(value) do
    if not allowed[key] then
      return false
    end
  end
  return true
end

return M
