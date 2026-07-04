local M = {}
local unpack = table.unpack or unpack

local function scoped(fn, cleanup)
  local results = {}
  local ok, err = xpcall(function()
    results = { fn() }
  end, debug.traceback)

  cleanup()

  if not ok then
    error(err, 0)
  end

  return unpack(results)
end

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

function M.cleanup_dir(path)
  if path ~= nil then
    vim.fn.delete(path, 'rf')
  end
end

function M.with_notify_stub(fn, replacement)
  local original_notify = vim.notify
  vim.notify = replacement or function() end

  return scoped(fn, function()
    vim.notify = original_notify
  end)
end

function M.with_temp_buf(fn, options)
  local buf = vim.api.nvim_create_buf(false, true)
  local original_buf

  if options ~= nil and options.current then
    original_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(buf)
  end

  return scoped(function()
    return fn(buf)
  end, function()
    if original_buf ~= nil and vim.api.nvim_buf_is_valid(original_buf) then
      vim.api.nvim_set_current_buf(original_buf)
    end

    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)
end

function M.with_temp_bufs(count, fn)
  local bufs = {}
  for _ = 1, count do
    bufs[#bufs + 1] = vim.api.nvim_create_buf(false, true)
  end

  return scoped(function()
    return fn(unpack(bufs))
  end, function()
    for _, buf in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end)
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
