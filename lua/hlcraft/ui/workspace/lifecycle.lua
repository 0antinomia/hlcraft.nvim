local help = require('hlcraft.ui.help')
local notify = require('hlcraft.notify')
local ui_state = require('hlcraft.ui.state')
local timers = require('hlcraft.ui.timers')
local window_options = require('hlcraft.ui.window_options')
local buffer = require('hlcraft.ui.workspace.buffer')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('workspace lifecycle requires an instance', 3)
  end
  return instance.state
end

local function assert_rerender(instance)
  if type(instance.rerender) ~= 'function' then
    error('workspace lifecycle requires a rerender callback', 3)
  end
end

local function cleanup_preview(instance)
  require('hlcraft.ui.preview').cleanup(instance)
end

local function cleanup_dynamic_preview(instance)
  require('hlcraft.ui.dynamic_preview').clear(instance)
end

local function close_raw_dynamic(instance)
  require('hlcraft.ui.raw_dynamic').close(instance)
end

local function install_preview_keymap(instance)
  require('hlcraft.ui.preview').install_keymap(instance)
end

local function uninstall_preview_keymap(instance)
  require('hlcraft.ui.preview').uninstall_keymap(instance)
end

local function close_unsaved_prompt(instance)
  require('hlcraft.ui.scene.detail').close_unsaved_prompt(instance)
end

local function is_wiping_buffer(buf)
  local ok, autocmd_buf = pcall(vim.fn.expand, '<abuf>')
  return ok and tonumber(autocmd_buf) == buf
end

--- Reset all view state to defaults
--- @param instance table The Instance object holding UI state
--- @return nil
local function reset_view_state(instance, state)
  close_unsaved_prompt(instance)
  close_raw_dynamic(instance)
  ui_state.reset_view(state)
end

--- Toggle the help floating window open or closed
--- @param instance table The Instance object holding UI state
--- @return nil
function M.toggle_help(instance)
  instance_state(instance)
  help.toggle(instance)
end

--- Hide the workspace window without deleting the buffer, restoring the origin
--- @param instance table The Instance object holding UI state
--- @return nil
function M.hide(instance)
  local state = instance_state(instance)
  if state.closing then
    return
  end
  state.closing = true

  local ok, err = pcall(function()
    close_unsaved_prompt(instance)
    close_raw_dynamic(instance)
    cleanup_preview(instance)
    cleanup_dynamic_preview(instance)
    uninstall_preview_keymap(instance)
    help.close(instance)
    window.restore_origin(instance)
  end)
  state.closing = false
  if not ok then
    notify.warn(('close operation failed: %s'):format(tostring(err)))
  end
end

--- Close the workspace: hide window and delete buffer
--- @param instance table The Instance object holding UI state
--- @return nil
function M.close(instance)
  local state = instance_state(instance)
  if state.closing then
    return
  end

  local buf = state.buf
  M.hide(instance)

  if window.is_valid_buf(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

--- Full cleanup: close help, delete buffers, remove augroups, reset state
--- @param instance table The Instance object holding UI state
--- @return nil
function M.cleanup(instance)
  local state = instance_state(instance)
  if state.closing then
    return
  end
  state.closing = true
  local workspace_buf = state.buf

  local ok, err = pcall(function()
    close_unsaved_prompt(instance)
    close_raw_dynamic(instance)
    cleanup_preview(instance)
    cleanup_dynamic_preview(instance)
    uninstall_preview_keymap(instance)
    window.restore_origin(instance)
    window.restore_all_workspace_windows(instance)
    if state.origin_win_options ~= nil then
      window_options.restore(state.origin_win_options)
      state.origin_win_options = nil
    end
    help.close(instance)
    help.delete_buffer(instance)

    if instance.group then
      pcall(vim.api.nvim_del_augroup_by_id, instance.group)
    end

    timers.stop_debounce(instance)
    if window.is_valid_buf(workspace_buf) and not is_wiping_buffer(workspace_buf) then
      pcall(vim.api.nvim_buf_delete, workspace_buf, { force = true })
    end

    instance.group = nil
    ui_state.reset_workspace_handles(state)
  end)
  state.closing = false
  if not ok then
    notify.warn(('cleanup failed: %s'):format(tostring(err)))
  end

  reset_view_state(instance, state)
end

--- Open the workspace in the current window, setting up buffer and initial render
--- @param instance table The Instance object holding UI state
--- @return nil
function M.open(instance)
  local state = instance_state(instance)
  assert_rerender(instance)
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()
  if current_buf ~= state.buf then
    state.origin_win = current_win
    state.origin_buf = current_buf
    state.origin_win_options = window_options.snapshot(current_win)
  end

  local buf = buffer.ensure(instance)
  vim.api.nvim_set_current_buf(buf)
  window.capture_workspace_window(instance, current_win)

  instance:rerender()
  install_preview_keymap(instance)
  require('hlcraft.ui.input.buffer_fields').goto_first(instance)
  require('hlcraft.ui.navigation').clamp_cursor(instance)
end

return M
