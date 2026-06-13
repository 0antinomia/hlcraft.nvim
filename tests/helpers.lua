local M = {}

function M.fail(scope, message)
  error(('%s: %s'):format(scope or 'hlcraft test', message), 0)
end

function M.assert_true(condition, message, scope)
  if not condition then
    M.fail(scope, message)
  end
end

function M.assert_equal(actual, expected, message, scope)
  if actual ~= expected then
    M.fail(scope, ('%s (expected %s, got %s)'):format(message, vim.inspect(expected), vim.inspect(actual)))
  end
end

function M.assert_file_exists(path, message, scope)
  M.assert_true(path ~= nil and vim.uv.fs_stat(path) ~= nil, message, scope)
end

function M.assert_file_missing(path, message, scope)
  if path == nil then
    return
  end
  M.assert_true(vim.uv.fs_stat(path) == nil, message, scope)
end

function M.temp_dir(name)
  local path = vim.fn.stdpath('cache') .. '/' .. name
  vim.fn.delete(path, 'rf')
  return path
end

function M.write_file(path, lines)
  local file = assert(io.open(path, 'w'))
  for _, line in ipairs(lines) do
    file:write(line .. '\n')
  end
  file:close()
end

function M.read_file(path)
  local file = assert(io.open(path, 'r'))
  local content = file:read('*a')
  file:close()
  return content
end

return M
