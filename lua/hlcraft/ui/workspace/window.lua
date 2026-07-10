local handles = require('hlcraft.ui.handles')
local window_options = require('hlcraft.ui.window_options')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('workspace window requires an instance', 3)
  end
  return instance.state
end

--- @param state table
--- @return table
local function workspace_window_options(state)
  local snapshots = state.workspace_win_options
  if type(snapshots) ~= 'table' then
    error('workspace window option snapshots must be a table', 3)
  end
  return snapshots
end

local function clear_workspace_window_snapshot(state, win)
  if win == nil then
    return
  end

  workspace_window_options(state)[win] = nil
  if state.last_workspace_win == win then
    state.last_workspace_win = nil
  end
end

local function restore_workspace_window_options(state, win)
  if win == nil then
    return true
  end

  local snapshot = workspace_window_options(state)[win]
  if not snapshot then
    return true
  end

  local restored = window_options.restore(snapshot)
  clear_workspace_window_snapshot(state, win)
  return restored
end

local function restore_origin_window_options(state, keep_snapshot)
  if keep_snapshot ~= nil and type(keep_snapshot) ~= 'boolean' then
    error('origin restore keep_snapshot must be boolean', 3)
  end
  if state.origin_win_options == nil then
    return false
  end

  local restored = window_options.restore(state.origin_win_options)
  if not keep_snapshot then
    state.origin_win_options = nil
  end
  return restored
end

local function has_origin(state)
  return M.is_valid_win(state.origin_win) and M.is_valid_buf(state.origin_buf) and state.origin_buf ~= state.buf
end

local function set_current_window(win)
  if not M.is_valid_win(win) then
    return false
  end
  local ok = pcall(vim.api.nvim_set_current_win, win)
  return ok and M.is_valid_win(win)
end

local function set_window_buffer(win, buf)
  if not M.is_valid_win(win) or not M.is_valid_buf(buf) then
    return false
  end
  local ok = pcall(vim.api.nvim_win_set_buf, win, buf)
  return ok and M.is_valid_win(win) and vim.api.nvim_win_get_buf(win) == buf
end

local function close_window(win)
  if not M.is_valid_win(win) then
    return true
  end
  local ok = pcall(vim.api.nvim_win_close, win, true)
  return ok and not M.is_valid_win(win)
end

local function find_workspace_windows(state)
  if not M.is_valid_buf(state.buf) then
    return {}
  end

  local found = vim.fn.win_findbuf(state.buf)
  if type(found) ~= 'table' then
    return {}
  end

  local windows = {}
  local seen = {}
  for _, win in ipairs(found) do
    if not seen[win] and M.is_valid_win(win) then
      seen[win] = true
      windows[#windows + 1] = win
    end
  end
  return windows
end

local function run_restore_step(errors, label, callback)
  local ok, result = pcall(callback)
  if not ok then
    errors[#errors + 1] = ('%s: %s'):format(label, tostring(result))
  elseif result ~= true then
    errors[#errors + 1] = label
  end
end

local function close_or_replace_window(win)
  if not M.is_valid_win(win) then
    return true
  end

  local tab = vim.api.nvim_win_get_tabpage(win)
  if #vim.api.nvim_tabpage_list_wins(tab) > 1 or #vim.api.nvim_list_tabpages() > 1 then
    return close_window(win)
  end

  local replacement = vim.api.nvim_create_buf(false, true)
  local replaced = set_window_buffer(win, replacement)
  if not replaced and M.is_valid_buf(replacement) then
    pcall(vim.api.nvim_buf_delete, replacement, { force = true })
  end
  return replaced
end

--- Check if a buffer handle is valid
--- @param buf number|nil Buffer handle
--- @return boolean True if buffer is valid
function M.is_valid_buf(buf)
  return handles.is_valid_buf(buf)
end

--- Check if a window handle is valid
--- @param win number|nil Window handle
--- @return boolean True if window is valid
function M.is_valid_win(win)
  return handles.is_valid_win(win)
end

--- Get the window displaying the workspace buffer
--- @param instance table The Instance object holding UI state
--- @return number|nil Window handle, or nil if buffer is not displayed
function M.get_win(instance)
  local state = instance_state(instance)
  local buf = state.buf
  if not M.is_valid_buf(buf) then
    return nil
  end

  local windows = find_workspace_windows(state)
  for _, win in ipairs(windows) do
    if win == state.last_workspace_win then
      return win
    end
  end
  if #windows > 0 then
    return windows[1]
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
  instance_state(instance)
  if not M.is_valid_win(win) then
    error('workspace window requires a valid window', 2)
  end
  window_options.apply(win, instance.ns)
end

--- Restore all captured workspace window-local option snapshots
--- @param instance table The Instance object holding UI state
--- @return nil
function M.restore_all_workspace_windows(instance)
  local state = instance_state(instance)
  local workspace_wins = vim.tbl_keys(workspace_window_options(state))
  local errors = {}
  for _, workspace_win in ipairs(workspace_wins) do
    local ok, err = pcall(restore_workspace_window_options, state, workspace_win)
    if not ok then
      errors[#errors + 1] = ('%s: %s'):format(tostring(workspace_win), tostring(err))
    end
  end
  if #errors > 0 then
    error(('failed to restore workspace windows: %s'):format(table.concat(errors, '; ')), 2)
  end
end

--- Restore the origin buffer and window that was active before opening
--- @param instance table The Instance object holding UI state
--- @return boolean restored True when required origin/window operations completed
--- @return string|nil err
function M.restore_origin(instance)
  local state = instance_state(instance)
  local workspace_wins = find_workspace_windows(state)
  local had_origin = has_origin(state)
  local errors = {}
  local visible_workspace_wins = {}

  if had_origin then
    run_restore_step(errors, 'origin focus', function()
      return set_current_window(state.origin_win)
    end)
    run_restore_step(errors, 'origin buffer', function()
      return set_window_buffer(state.origin_win, state.origin_buf)
    end)
  end

  for _, workspace_win in ipairs(workspace_wins) do
    visible_workspace_wins[workspace_win] = true
    if not had_origin or workspace_win ~= state.origin_win then
      local label = ('workspace window %s'):format(tostring(workspace_win))
      run_restore_step(errors, label .. ' options', function()
        return restore_workspace_window_options(state, workspace_win)
      end)
      run_restore_step(errors, label .. ' close', function()
        if had_origin then
          return close_window(workspace_win)
        end
        return close_or_replace_window(workspace_win)
      end)
    end
  end

  for _, workspace_win in ipairs(vim.tbl_keys(workspace_window_options(state))) do
    if not visible_workspace_wins[workspace_win] then
      if M.is_valid_win(workspace_win) then
        local label = ('detached workspace window %s options'):format(tostring(workspace_win))
        run_restore_step(errors, label, function()
          return restore_workspace_window_options(state, workspace_win)
        end)
      else
        clear_workspace_window_snapshot(state, workspace_win)
      end
    end
  end

  if state.origin_win_options ~= nil then
    run_restore_step(errors, 'origin options', function()
      return restore_origin_window_options(state, true)
    end)
  end

  if #errors > 0 then
    return false, table.concat(errors, '; ')
  end
  return true
end

function M.capture_workspace_window(instance, win)
  local state = instance_state(instance)
  if not M.is_valid_win(win) then
    return
  end

  if win == state.origin_win then
    if state.origin_win_options == nil then
      state.origin_win_options = window_options.snapshot(win)
    elseif type(state.origin_win_options.values) ~= 'table' then
      error('origin window option snapshot values must be a table', 2)
    end
    M.apply_window_options(instance, win)
    return
  end

  local snapshots = workspace_window_options(state)
  local snapshot = snapshots[win]
  if snapshot == nil then
    snapshot = window_options.snapshot(win)
    if snapshot == nil or snapshot.win == nil then
      return
    end

    if state.origin_win_options ~= nil and window_options.matches_workspace(snapshot.values) then
      if type(state.origin_win_options.values) ~= 'table' then
        error('origin window option snapshot values must be a table', 2)
      end
      snapshot = {
        win = snapshot.win,
        values = vim.deepcopy(state.origin_win_options.values),
      }
    end
  end

  M.apply_window_options(instance, win)
  snapshots[win] = snapshot
  state.last_workspace_win = win
end

function M.release_workspace_window(instance, win)
  local state = instance_state(instance)
  if not M.is_valid_win(win) then
    return
  end

  if win == state.origin_win then
    restore_origin_window_options(state, true)
    return
  end

  restore_workspace_window_options(state, win)
end

return M
