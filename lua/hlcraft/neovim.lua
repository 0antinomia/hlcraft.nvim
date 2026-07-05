local M = {}

M.minimum_version = '0.10.0'

function M.version()
  if vim.version == nil then
    return nil
  end

  local ok, version = pcall(vim.version)
  if not ok then
    return nil
  end
  return version
end

function M.supports_minimum()
  local version = M.version()
  local ok, ge = pcall(function()
    return vim.version and vim.version.ge
  end)

  if not ok or type(ge) ~= 'function' or version == nil then
    return false, version
  end

  return ge(version, M.minimum_version), version
end

function M.requirement_message(version)
  local message = ('requires Neovim >= %s'):format(M.minimum_version)
  if version ~= nil then
    message = message .. '. Current version: ' .. tostring(version)
  end
  return message
end

return M
