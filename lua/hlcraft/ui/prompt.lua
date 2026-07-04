local notify = require('hlcraft.notify')

local M = {}

function M.input(input_opts, submit, opts)
  opts = opts or {}
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
