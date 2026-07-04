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

function M.input(input_opts, submit, opts)
  if type(input_opts) ~= 'table' then
    error('vim input options must be a table', 2)
  end
  if type(submit) ~= 'function' then
    error('prompt submit callback must be a function', 2)
  end
  opts = optional_opts(opts)
  vim.ui.input(input_opts, function(value)
    if value == nil then
      return
    end

    local ok, err = submit(value)
    if opts.notify_errors ~= false and ok == false and err then
      notify.error(err)
    end
  end)
  return true, nil
end

return M
