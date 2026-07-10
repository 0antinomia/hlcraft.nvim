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

local function buffer_name(instance)
  if type(instance.id) ~= 'string' or instance.id == '' then
    error('workspace buffer instance id must be a non-empty string', 3)
  end
  return 'HLCRAFT://' .. instance.id
end

local function autocmd_group_exists(group)
  return type(group) == 'number' and pcall(vim.api.nvim_get_autocmds, { group = group })
end

local function append_rollback_errors(err, rollback_errors)
  if #rollback_errors == 0 then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, table.concat(rollback_errors, '; '))
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
  local previous_buf = state.buf
  local previous_group = instance.group
  local previous_autocmd_buf = instance.autocmd_buf
  local buf
  local ok, err = xpcall(function()
    buf = vim.api.nvim_create_buf(true, true)
    state.buf = buf
    vim.api.nvim_buf_set_name(buf, buffer_name(instance))
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true
    vim.bo[buf].filetype = 'hlcraft'
    vim.b[buf].completion = false

    require('hlcraft.ui.keymaps').setup_workspace_keymaps(instance, buf)
    require('hlcraft.ui.autocmds').setup(instance)
  end, debug.traceback)
  if not ok then
    local rollback_errors = {}
    local created_group = instance.group
    if created_group ~= nil and created_group ~= previous_group then
      local deleted, delete_err = pcall(vim.api.nvim_del_augroup_by_id, created_group)
      if not deleted then
        rollback_errors[#rollback_errors + 1] = ('autocmd group: %s'):format(tostring(delete_err))
      end
    end
    if window.is_valid_buf(buf) then
      local deleted, delete_err = pcall(vim.api.nvim_buf_delete, buf, { force = true })
      if not deleted then
        rollback_errors[#rollback_errors + 1] = ('workspace buffer: %s'):format(tostring(delete_err))
      end
    end

    if window.is_valid_buf(buf) then
      state.buf = buf
    else
      state.buf = previous_buf
    end
    if autocmd_group_exists(created_group) then
      instance.group = created_group
    elseif autocmd_group_exists(previous_group) then
      instance.group = previous_group
      instance.autocmd_buf = previous_autocmd_buf
    else
      instance.group = nil
      instance.autocmd_buf = nil
    end
    error(append_rollback_errors(err, rollback_errors), 0)
  end

  return buf
end

return M
