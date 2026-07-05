local M = {}

function M.result_name(result, label)
  if type(label) ~= 'string' or label == '' then
    error('editor context label must be a non-empty string', 3)
  end
  if type(result) ~= 'table' or type(result.name) ~= 'string' or result.name == '' then
    error(('%s requires a highlight result'):format(label), 3)
  end
  return result.name
end

function M.field_key(key, label)
  if type(label) ~= 'string' or label == '' then
    error('editor context label must be a non-empty string', 3)
  end
  if type(key) ~= 'string' or key == '' then
    error(('%s field must be a non-empty string'):format(label), 3)
  end
  return key
end

return M
