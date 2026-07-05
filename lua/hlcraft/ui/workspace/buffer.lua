local window = require('hlcraft.ui.workspace.window')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('workspace buffer requires an instance', 3)
  end
  return instance.state
end

local function assert_group_name(instance)
  if type(instance.group_name) ~= 'string' or instance.group_name == '' then
    error('workspace buffer group name must be a non-empty string', 3)
  end
end

--- Create the workspace buffer if it does not already exist
--- @param instance table The Instance object holding UI state
--- @return number Buffer handle
function M.ensure(instance)
  local state = instance_state(instance)
  if window.is_valid_buf(state.buf) then
    return state.buf
  end

  assert_group_name(instance)
  local buf = vim.api.nvim_create_buf(true, true)
  state.buf = buf
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
