local M = {}

local function assert_string(value, label)
  if type(value) ~= 'string' then
    error(('%s must be a string'):format(label), 3)
  end
  return value
end

function M.escape_string(value)
  return assert_string(value, 'TOML string'):gsub('\\', '\\\\'):gsub('"', '\\"')
end

function M.unescape_string(value)
  return assert_string(value, 'TOML string'):gsub('\\"', '"'):gsub('\\\\', '\\')
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
