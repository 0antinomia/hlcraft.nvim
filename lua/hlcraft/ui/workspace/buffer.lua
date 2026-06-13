local window = require('hlcraft.ui.workspace.window')

local M = {}

--- Create the workspace buffer if it does not already exist
--- @param instance table The Instance object holding UI state
--- @return number Buffer handle
function M.ensure(instance)
  if window.is_valid_buf(instance.state.buf) then
    return instance.state.buf
  end

  local buf = vim.api.nvim_create_buf(true, true)
  instance.state.buf = buf
  vim.api.nvim_buf_set_name(buf, 'HLCRAFT')
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = 'hlcraft'
  vim.b[buf].completion = false

  require('hlcraft.ui.keymaps').setup_workspace_keymaps(instance, buf)
  require('hlcraft.ui.autocmds').setup(instance)

  return buf
end

return M
