local M = {}

local help = require('hlcraft.ui.help')
local window_options = require('hlcraft.ui.window_options')

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

local function install_preview_keymap(instance)
  require('hlcraft.ui.preview').install_keymap(instance)
end

local function uninstall_preview_keymap(instance)
  require('hlcraft.ui.preview').uninstall_keymap(instance)
end

local function close_unsaved_prompt(instance)
  require('hlcraft.ui.state.results').close_unsaved_prompt(instance)
end

local function clear_workspace_window_snapshot(instance, win)
  if win == nil then
    return
  end

  instance.state.workspace_win_options[win] = nil
  if instance.state.last_workspace_win == win then
    instance.state.last_workspace_win = nil
  end
end

local function restore_workspace_window_options(instance, win)
  if win == nil then
    return false
  end

  local snapshot = instance.state.workspace_win_options[win]
  if not snapshot then
    return false
  end

  local restored = window_options.restore(snapshot)
  clear_workspace_window_snapshot(instance, win)
  return restored
end

local function restore_all_workspace_windows(instance)
  for workspace_win, _ in pairs(instance.state.workspace_win_options or {}) do
    restore_workspace_window_options(instance, workspace_win)
  end
end

local function restore_origin_window_options(instance, clear_snapshot)
  if instance.state.origin_win_options == nil then
    return false
  end

  local restored = window_options.restore(instance.state.origin_win_options)
  if clear_snapshot ~= false then
    instance.state.origin_win_options = nil
  end
  return restored
end

local function has_origin(instance)
  return M.is_valid_win(instance.state.origin_win)
    and M.is_valid_buf(instance.state.origin_buf)
    and instance.state.origin_buf ~= instance.state.buf
end

--- Check if a buffer handle is valid
--- @param buf number|nil Buffer handle
--- @return boolean True if buffer is valid
function M.is_valid_buf(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

--- Check if a window handle is valid
--- @param win number|nil Window handle
--- @return boolean True if window is valid
function M.is_valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

--- Get the window displaying the workspace buffer
--- @param instance table The Instance object holding UI state
--- @return number|nil Window handle, or nil if buffer is not displayed
function M.get_win(instance)
  local buf = instance.state.buf
  if not M.is_valid_buf(buf) then
    return nil
  end

  local windows = vim.fn.win_findbuf(buf)
  if type(windows) == 'table' and #windows > 0 then
    for _, win in ipairs(windows) do
      if win == instance.state.last_workspace_win and M.is_valid_win(win) then
        return win
      end
    end

    for _, win in ipairs(windows) do
      if M.is_valid_win(win) then
        return win
      end
    end
  end

  return nil
end

--- Check if the workspace window is currently open
--- @param instance table The Instance object holding UI state
--- @return boolean True if workspace window is visible
function M.is_open(instance)
  return M.is_valid_win(M.get_win(instance))
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

--- Create the workspace buffer if it does not already exist
--- @param instance table The Instance object holding UI state
--- @return number Buffer handle
local function ensure_buffer(instance)
  if M.is_valid_buf(instance.state.buf) then
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

--- Apply workspace window-local options (no numbers, no wrap, etc.)
--- @param instance table The Instance object holding UI state
--- @param win number Window handle
--- @return nil
local function apply_window_options(instance, win)
  window_options.apply(win, instance.ns)
end

--- Restore the origin buffer and window that was active before opening
--- @param instance table The Instance object holding UI state
--- @return nil
local function restore_origin(instance)
  local win = M.get_win(instance)
  local had_origin = has_origin(instance)

  if had_origin then
    if M.is_valid_win(win) and win == instance.state.origin_win then
      pcall(vim.api.nvim_win_set_buf, win, instance.state.origin_buf)
    else
      pcall(vim.api.nvim_set_current_win, instance.state.origin_win)
      pcall(vim.api.nvim_win_set_buf, instance.state.origin_win, instance.state.origin_buf)
      if M.is_valid_win(win) then
        restore_workspace_window_options(instance, win)
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end

  if instance.state.origin_win_options ~= nil then
    restore_origin_window_options(instance, false)
  end

  if had_origin then
    return
  end

  if M.is_valid_win(win) then
    restore_workspace_window_options(instance, win)
  end

  if not M.is_valid_win(win) then
    return
  end

  if #vim.api.nvim_tabpage_list_wins(0) > 1 then
    pcall(vim.api.nvim_win_close, win, true)
  else
    vim.cmd('enew')
  end
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
    uninstall_preview_keymap(instance)
    help.close(instance)
    restore_origin(instance)
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

  if M.is_valid_buf(buf) then
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

  local ok, err = pcall(function()
    close_unsaved_prompt(instance)
    cleanup_preview(instance)
    uninstall_preview_keymap(instance)
    restore_all_workspace_windows(instance)
    if instance.state.origin_win_options ~= nil then
      restore_origin_window_options(instance)
    end
    help.close(instance)
    help.delete_buffer(instance)

    if instance.group then
      pcall(vim.api.nvim_del_augroup_by_id, instance.group)
    end

    stop_debounce_timer(instance)

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

  local buf = ensure_buffer(instance)
  vim.api.nvim_set_current_buf(buf)
  M.capture_workspace_window(instance, current_win)

  instance:rerender()
  install_preview_keymap(instance)
  require('hlcraft.ui.input.actions').goto_first_input(instance)
  require('hlcraft.ui.navigation').clamp_cursor(instance)
end

function M.capture_workspace_window(instance, win)
  if not M.is_valid_win(win) then
    return
  end

  if win == instance.state.origin_win then
    apply_window_options(instance, win)
    return
  end

  instance.state.last_workspace_win = win

  if instance.state.workspace_win_options[win] == nil then
    local snapshot = window_options.snapshot(win)
    if snapshot == nil or snapshot.win == nil then
      return
    end

    if instance.state.origin_win_options ~= nil and window_options.matches_workspace(snapshot.values) then
      snapshot.values = vim.deepcopy(instance.state.origin_win_options.values or {})
    end

    instance.state.workspace_win_options[win] = snapshot
  end

  apply_window_options(instance, win)
end

function M.release_workspace_window(instance, win)
  if not M.is_valid_win(win) then
    return
  end

  if win == instance.state.origin_win then
    restore_origin_window_options(instance, false)
    return
  end

  restore_workspace_window_options(instance, win)
end

return M
