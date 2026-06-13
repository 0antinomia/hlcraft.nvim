local window_options = require('hlcraft.ui.window_options')

local M = {}

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

--- Apply workspace window-local options (no numbers, no wrap, etc.)
--- @param instance table The Instance object holding UI state
--- @param win number Window handle
--- @return nil
function M.apply_window_options(instance, win)
  window_options.apply(win, instance.ns)
end

--- Restore all captured workspace window-local option snapshots
--- @param instance table The Instance object holding UI state
--- @return nil
function M.restore_all_workspace_windows(instance)
  for workspace_win, _ in pairs(instance.state.workspace_win_options or {}) do
    restore_workspace_window_options(instance, workspace_win)
  end
end

--- Restore the origin buffer and window that was active before opening
--- @param instance table The Instance object holding UI state
--- @return nil
function M.restore_origin(instance)
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

function M.capture_workspace_window(instance, win)
  if not M.is_valid_win(win) then
    return
  end

  if win == instance.state.origin_win then
    M.apply_window_options(instance, win)
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

  M.apply_window_options(instance, win)
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
