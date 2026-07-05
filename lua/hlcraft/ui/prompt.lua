local notify = require('hlcraft.notify')

local M = {}

local function optional_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error('prompt options must be a table', 3)
  end
  return opts
end

local function prompt_opts(opts)
  opts = optional_opts(opts)
  for key in pairs(opts) do
    if key ~= 'notify_errors' then
      error(('unknown prompt option: %s'):format(tostring(key)), 3)
    end
  end
  if opts.notify_errors ~= nil and type(opts.notify_errors) ~= 'boolean' then
    error('prompt notify_errors must be boolean', 3)
  end
  return opts
end

local function submitted_value(value)
  if value == nil then
    return nil
  end
  if type(value) ~= 'string' then
    error('prompt value must be a string or nil', 3)
  end
  return value
end

local function submit_result(ok)
  if type(ok) ~= 'boolean' then
    error('prompt submit result must be boolean', 3)
  end
  return ok
end

function M.input(input_opts, submit, opts)
  if type(input_opts) ~= 'table' then
    error('vim input options must be a table', 2)
  end
  if type(submit) ~= 'function' then
    error('prompt submit callback must be a function', 2)
  end
  opts = prompt_opts(opts)
  vim.ui.input(input_opts, function(value)
    value = submitted_value(value)
    if value == nil then
      return
    end

    local ok, err = submit(value)
    ok = submit_result(ok)
    if opts.notify_errors ~= false and ok == false and err then
      notify.error(err)
    end
  end)
  return true, nil
end

return M
