local M = {}

local function assert_field(field)
  if type(field) ~= 'table' then
    error('input field must be a table', 3)
  end
  return field
end

local function assert_inputs(inputs)
  if type(inputs) ~= 'table' then
    error('input sequence must be a table', 3)
  end
  return inputs
end

local function assert_current_name(current_name)
  if current_name ~= nil and type(current_name) ~= 'string' then
    error('current input name must be a string or nil', 3)
  end
  return current_name
end

local function assert_predicate(predicate)
  if predicate ~= nil and type(predicate) ~= 'function' then
    error('input predicate must be a function or nil', 3)
  end
  return predicate
end

function M.name(field)
  field = assert_field(field)
  local name = field.key or field.name
  if type(name) ~= 'string' or name == '' then
    error('input field name must be a non-empty string', 2)
  end
  return name
end

function M.first_name(inputs, predicate)
  inputs = assert_inputs(inputs)
  predicate = assert_predicate(predicate)
  for _, field in ipairs(inputs) do
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
  inputs = assert_inputs(inputs)
  current_name = assert_current_name(current_name)
  return relative_name(inputs, current_name, 1, 1)
end

function M.prev_name(inputs, current_name)
  inputs = assert_inputs(inputs)
  current_name = assert_current_name(current_name)
  return relative_name(inputs, current_name, #inputs, -1)
end

return M
