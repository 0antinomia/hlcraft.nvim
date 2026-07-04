local M = {}

function M.is_sequence(value)
  if type(value) ~= 'table' then
    return false
  end

  local count = 0
  for key in pairs(value) do
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
      return false
    end
    count = count + 1
  end

  return count == #value
end

return M
