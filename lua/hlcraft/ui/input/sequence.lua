local M = {}

function M.name(field)
  return field and (field.key or field.name) or nil
end

function M.first_name(inputs, predicate)
  for _, field in ipairs(inputs or {}) do
    if not predicate or predicate(field) then
      return M.name(field)
    end
  end
end

local function relative_name(inputs, current_name, fallback_index, step)
  if #inputs == 0 then
    return nil
  end

  local fallback = M.name(inputs[fallback_index])
  if not current_name then
    return fallback
  end

  for index, field in ipairs(inputs) do
    if M.name(field) == current_name then
      local target = inputs[index + step] or inputs[step > 0 and 1 or #inputs]
      return M.name(target)
    end
  end

  return fallback
end

function M.next_name(inputs, current_name)
  return relative_name(inputs or {}, current_name, 1, 1)
end

function M.prev_name(inputs, current_name)
  return relative_name(inputs or {}, current_name, #(inputs or {}), -1)
end

return M
