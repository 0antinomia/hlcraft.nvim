local help = require('hlcraft.ui.help')
local window_options = require('hlcraft.ui.window_options')
local buffer = require('hlcraft.ui.workspace.buffer')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function stop_debounce_timer(instance)
  local timer = instance.state.debounce_timer
  if not timer then
    return
  end

  if timer.stop then
    timer:stop()
  end
  if timer.close then
    pcall(function()
      timer:close()
    end)
  end

  instance.state.debounce_timer = nil
end

local function cleanup_preview(instance)
  require('hlcraft.ui.preview').cleanup(instance)
end

local function cleanup_dynamic_preview(instance)
  require('hlcraft.ui.dynamic_preview').clear(instance)
end

local function install_preview_keymap(instance)
  require('hlcraft.ui.preview').install_keymap(instance)
end

local function uninstall_preview_keymap(instance)
  require('hlcraft.ui.preview').uninstall_keymap(instance)
end

local function close_unsaved_prompt(instance)
  require('hlcraft.ui.state.results').close_unsaved_prompt(instance)
end

local function is_wiping_buffer(buf)
  local ok, autocmd_buf = pcall(vim.fn.expand, '<abuf>')
  return ok and tonumber(autocmd_buf) == buf
end

--- Reset all view state to defaults
--- @param instance table The Instance object holding UI state
--- @return nil
local function reset_view_state(instance)
  close_unsaved_prompt(instance)
  instance.state.results = {}
  instance.state.detail_index = nil
  instance.state.list_cursor = 1
  instance.state.name_query = ''
  instance.state.color_query = ''
  instance.state.geometry = {
    inputs = {},
    result_lines = {},
    detail_menu = {},
    editor_rows = {},
  }
  instance.state.rendering = false
  instance.state.input_marks = {}
  instance.state.placeholder_marks = {}
  instance.state.extmark_ids = {}
  instance.state.clamping_cursor = false
  instance.state.preview = {
    name = nil,
    spec = nil,
    timer = nil,
    keymap = nil,
  }
end

--- Toggle the help floating window open or closed
--- @param instance table The Instance object holding UI state
--- @return nil
function M.toggle_help(instance)
  help.toggle(instance)
end

--- Hide the workspace window without deleting the buffer, restoring the origin
--- @param instance table The Instance object holding UI state
--- @return nil
function M.hide(instance)
  if instance.state.closing then
    return
  end
  instance.state.closing = true

  local ok, err = pcall(function()
    close_unsaved_prompt(instance)
    cleanup_preview(instance)
    cleanup_dynamic_preview(instance)
    uninstall_preview_keymap(instance)
    help.close(instance)
    window.restore_origin(instance)
  end)
  instance.state.closing = false
  if not ok then
    vim.notify(('hlcraft: close operation failed: %s'):format(tostring(err)), vim.log.levels.WARN)
  end
end

--- Close the workspace: hide window and delete buffer
--- @param instance table The Instance object holding UI state
--- @return nil
function M.close(instance)
  if instance.state.closing then
    return
  end

  local buf = instance.state.buf
  M.hide(instance)

  if window.is_valid_buf(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

--- Full cleanup: close help, delete buffers, remove augroups, reset state
--- @param instance table The Instance object holding UI state
--- @return nil
function M.cleanup(instance)
  if instance.state.closing then
    return
  end
  instance.state.closing = true
  local workspace_buf = instance.state.buf

  local ok, err = pcall(function()
    close_unsaved_prompt(instance)
    cleanup_preview(instance)
    cleanup_dynamic_preview(instance)
    uninstall_preview_keymap(instance)
    window.restore_origin(instance)
    window.restore_all_workspace_windows(instance)
    if instance.state.origin_win_options ~= nil then
      window_options.restore(instance.state.origin_win_options)
      instance.state.origin_win_options = nil
    end
    help.close(instance)
    help.delete_buffer(instance)

    if instance.group then
      pcall(vim.api.nvim_del_augroup_by_id, instance.group)
    end

    stop_debounce_timer(instance)
    if window.is_valid_buf(workspace_buf) and not is_wiping_buffer(workspace_buf) then
      pcall(vim.api.nvim_buf_delete, workspace_buf, { force = true })
    end

    instance.group = nil
    instance.state.buf = nil
    instance.state.help_buf = nil
    instance.state.help_win = nil
    instance.state.origin_buf = nil
    instance.state.origin_win = nil
    instance.state.origin_win_options = nil
    instance.state.workspace_win_options = {}
    instance.state.last_workspace_win = nil
  end)
  instance.state.closing = false
  if not ok then
    vim.notify(('hlcraft: cleanup failed: %s'):format(tostring(err)), vim.log.levels.WARN)
  end

  reset_view_state(instance)
end

--- Open the workspace in the current window, setting up buffer and initial render
--- @param instance table The Instance object holding UI state
--- @return nil
function M.open(instance)
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()
  if current_buf ~= instance.state.buf then
    instance.state.origin_win = current_win
    instance.state.origin_buf = current_buf
    instance.state.origin_win_options = window_options.snapshot(current_win)
  end

  local buf = buffer.ensure(instance)
  vim.api.nvim_set_current_buf(buf)
  window.capture_workspace_window(instance, current_win)

  instance:rerender()
  install_preview_keymap(instance)
  require('hlcraft.ui.input.actions').goto_first_input(instance)
  require('hlcraft.ui.navigation').clamp_cursor(instance)
end

return M
