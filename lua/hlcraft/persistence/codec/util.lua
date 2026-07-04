local M = {}

function M.escape_string(value)
  return tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
end

function M.unescape_string(value)
  return tostring(value):gsub('\\"', '"'):gsub('\\\\', '\\')
end

function M.normalize_group_name(name)
  local normalized = vim.trim(tostring(name or ''))
  if normalized == '' then
    return nil
  end
  return normalized
end

return M
