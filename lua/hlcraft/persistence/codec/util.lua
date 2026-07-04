local M = {}

function M.escape_string(value)
  return tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
end

function M.unescape_string(value)
  return tostring(value):gsub('\\"', '"'):gsub('\\\\', '\\')
end

function M.normalize_group_name(name)
  if type(name) ~= 'string' then
    return nil
  end
  local normalized = vim.trim(name)
  if normalized == '' then
    return nil
  end
  return normalized
end

return M
