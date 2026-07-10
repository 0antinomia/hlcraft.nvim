local help = require('hlcraft.ui.help')
local notify = require('hlcraft.notify')
local numbers = require('hlcraft.core.number')
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

local function assert_namespace(instance)
  numbers.assert_non_negative_integer(instance.ns, 'workspace lifecycle namespace', 3)
end

local function assert_group_name(instance)
  if type(instance.group_name) ~= 'string' or instance.group_name == '' then
    error('workspace lifecycle group name must be a non-empty string', 3)
  end
end

local function cleanup_preview(instance)
  local cleaned, err = require('hlcraft.ui.preview').cleanup(instance)
  if not cleaned then
    error(('failed to restore preview highlight: %s'):format(tostring(err)), 2)
  end
end

local function cleanup_dynamic_preview(instance)
  require('hlcraft.ui.dynamic_preview').clear(instance)
end

local function close_raw_dynamic(instance)
  local closed, err = require('hlcraft.ui.raw_dynamic').close(instance)
  if not closed then
    error(('failed to close raw dynamic editor: %s'):format(tostring(err)), 2)
  end
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

local function close_help(instance)
  local closed, err = help.close(instance)
  if not closed then
    error(('failed to close help window: %s'):format(tostring(err)), 2)
  end
end

local function delete_help_buffer(instance)
  local deleted, err = help.delete_buffer(instance)
  if not deleted then
    error(('failed to delete help buffer: %s'):format(tostring(err)), 2)
  end
end

local function restore_origin_window(instance)
  local restored, err = window.restore_origin(instance)
  if not restored then
    local detail = err and (': ' .. err) or ''
    error('failed to restore origin window' .. detail, 2)
  end
end

local function is_wiping_buffer(buf)
  local ok, autocmd_buf = pcall(vim.fn.expand, '<abuf>')
  return ok and tonumber(autocmd_buf) == buf
end

local function autocmd_group_exists(group)
  return type(group) == 'number' and pcall(vim.api.nvim_get_autocmds, { group = group })
end

local function run_cleanup_step(errors, label, callback)
  local ok, err = pcall(callback)
  if not ok then
    errors[#errors + 1] = ('%s: %s'):format(label, tostring(err))
  end
  return ok
end

local function notify_cleanup_errors(prefix, errors)
  if #errors == 0 then
    return true
  end
  notify.warn(('%s: %s'):format(prefix, table.concat(errors, '; ')))
  return false
end

local function snapshot_open_state(instance, state, current_win, current_buf)
  return {
    autocmd_buf = instance.autocmd_buf,
    group = instance.group,
    current_win = current_win,
    current_buf = current_buf,
    buf = state.buf,
    clamping_cursor = state.clamping_cursor,
    color_query = state.color_query,
    detail_index = state.detail_index,
    dynamic_preview = vim.deepcopy(state.dynamic_preview),
    extmark_ids = vim.deepcopy(state.extmark_ids),
    field_editor = vim.deepcopy(state.field_editor),
    geometry = vim.deepcopy(state.geometry),
    input_marks = vim.deepcopy(state.input_marks),
    list_cursor = state.list_cursor,
    name_query = state.name_query,
    origin_buf = state.origin_buf,
    origin_win = state.origin_win,
    origin_win_options = vim.deepcopy(state.origin_win_options),
    placeholder_marks = vim.deepcopy(state.placeholder_marks),
    preview = vim.deepcopy(state.preview),
    rendering = state.rendering,
    results = vim.deepcopy(state.results),
    scene = vim.deepcopy(state.scene),
    workspace_win_options = vim.deepcopy(state.workspace_win_options),
    last_workspace_win = state.last_workspace_win,
  }
end

local function rollback_open(instance, state, snapshot, opts)
  opts = opts or {}
  local errors = {}
  local created_workspace = state.buf ~= snapshot.buf
  local preserve_preview = false
  if opts.installed_preview_keymap then
    if not run_cleanup_step(errors, 'preview keymap', function()
      uninstall_preview_keymap(instance)
    end) then
      preserve_preview = true
    end
  end
  if created_workspace then
    if not run_cleanup_step(errors, 'preview', function()
      cleanup_preview(instance)
    end) then
      preserve_preview = true
    end
    run_cleanup_step(errors, 'dynamic preview', function()
      cleanup_dynamic_preview(instance)
    end)
  end

  run_cleanup_step(errors, 'workspace window options', function()
    window.restore_all_workspace_windows(instance)
  end)
  if state.origin_win_options ~= nil then
    run_cleanup_step(errors, 'origin window options', function()
      if not window_options.restore(state.origin_win_options) then
        error('origin window options were not restored', 2)
      end
    end)
  end
  if window.is_valid_win(snapshot.current_win) then
    run_cleanup_step(errors, 'current window', function()
      vim.api.nvim_set_current_win(snapshot.current_win)
    end)
    if window.is_valid_buf(snapshot.current_buf) then
      run_cleanup_step(errors, 'current buffer', function()
        vim.api.nvim_win_set_buf(snapshot.current_win, snapshot.current_buf)
      end)
    end
  end

  local created_buf = state.buf
  if created_buf ~= snapshot.buf and window.is_valid_buf(created_buf) then
    run_cleanup_step(errors, 'workspace buffer', function()
      vim.api.nvim_buf_delete(created_buf, { force = true })
      if window.is_valid_buf(created_buf) then
        error('workspace buffer remains valid', 2)
      end
    end)
  end
  local created_group = instance.group
  local restore_snapshot_group = true
  if created_group ~= nil and created_group ~= snapshot.group then
    run_cleanup_step(errors, 'autocmd group', function()
      vim.api.nvim_del_augroup_by_id(created_group)
      if autocmd_group_exists(created_group) then
        error('autocmd group remains valid', 2)
      end
    end)
    restore_snapshot_group = not autocmd_group_exists(created_group)
  end

  local restore_snapshot_buf = true
  if restore_snapshot_group then
    instance.group = snapshot.group
    instance.autocmd_buf = snapshot.autocmd_buf
  else
    instance.group = created_group
    instance.autocmd_buf = nil
  end
  if created_buf ~= snapshot.buf and window.is_valid_buf(created_buf) then
    restore_snapshot_buf = false
  end
  if restore_snapshot_buf then
    state.buf = snapshot.buf
  else
    state.buf = created_buf
  end
  state.clamping_cursor = snapshot.clamping_cursor
  state.color_query = snapshot.color_query
  state.detail_index = snapshot.detail_index
  state.dynamic_preview = snapshot.dynamic_preview
  state.extmark_ids = snapshot.extmark_ids
  state.field_editor = snapshot.field_editor
  state.geometry = snapshot.geometry
  state.input_marks = snapshot.input_marks
  state.list_cursor = snapshot.list_cursor
  state.name_query = snapshot.name_query
  state.origin_buf = snapshot.origin_buf
  state.origin_win = snapshot.origin_win
  state.origin_win_options = snapshot.origin_win_options
  state.placeholder_marks = snapshot.placeholder_marks
  if not preserve_preview then
    state.preview = snapshot.preview
  end
  state.rendering = snapshot.rendering
  state.results = snapshot.results
  state.scene = snapshot.scene
  state.workspace_win_options = snapshot.workspace_win_options
  state.last_workspace_win = snapshot.last_workspace_win
  return errors
end

--- Reset all view state to defaults
--- @param state table The workspace state table
--- @return nil
local function reset_view_state(state)
  ui_state.reset_view(state)
end

--- Toggle the help floating window open or closed
--- @param instance table The Instance object holding UI state
--- @return boolean ok False when closing the existing help window fails
function M.toggle_help(instance)
  instance_state(instance)
  local ok = help.toggle(instance)
  if ok == false then
    notify.warn('failed to close help window')
    return false
  end
  return true
end

--- Hide the workspace window without deleting the buffer, restoring the origin
--- @param instance table The Instance object holding UI state
--- @return boolean|nil ok False when cleanup fails, nil when already closing
function M.hide(instance)
  local state = instance_state(instance)
  if state.closing then
    return
  end
  state.closing = true

  local errors = {}
  run_cleanup_step(errors, 'unsaved prompt', function()
    close_unsaved_prompt(instance)
  end)
  run_cleanup_step(errors, 'raw dynamic editor', function()
    close_raw_dynamic(instance)
  end)
  run_cleanup_step(errors, 'preview', function()
    cleanup_preview(instance)
  end)
  run_cleanup_step(errors, 'dynamic preview', function()
    cleanup_dynamic_preview(instance)
  end)
  run_cleanup_step(errors, 'preview keymap', function()
    uninstall_preview_keymap(instance)
  end)
  run_cleanup_step(errors, 'debounce timer', function()
    timers.stop_debounce(instance)
  end)
  run_cleanup_step(errors, 'help window', function()
    close_help(instance)
  end)
  run_cleanup_step(errors, 'origin window', function()
    restore_origin_window(instance)
  end)
  state.closing = false
  return notify_cleanup_errors('close operation failed', errors)
end

--- Close the workspace: hide window and delete buffer
--- @param instance table The Instance object holding UI state
--- @return boolean|nil ok False when cleanup fails, nil when already closing
function M.close(instance)
  local state = instance_state(instance)
  if state.closing then
    return
  end

  local buf = state.buf
  if not M.hide(instance) then
    return false
  end

  local errors = {}
  run_cleanup_step(errors, 'workspace buffer', function()
    if window.is_valid_buf(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    if state.buf == buf and not window.is_valid_buf(buf) then
      state.buf = nil
      state.last_workspace_win = nil
    end
  end)
  return notify_cleanup_errors('close operation failed', errors)
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

  local errors = {}
  run_cleanup_step(errors, 'unsaved prompt', function()
    close_unsaved_prompt(instance)
  end)
  run_cleanup_step(errors, 'raw dynamic editor', function()
    close_raw_dynamic(instance)
  end)
  run_cleanup_step(errors, 'preview', function()
    cleanup_preview(instance)
  end)
  run_cleanup_step(errors, 'dynamic preview', function()
    cleanup_dynamic_preview(instance)
  end)
  run_cleanup_step(errors, 'preview keymap', function()
    uninstall_preview_keymap(instance)
  end)
  run_cleanup_step(errors, 'origin window', function()
    restore_origin_window(instance)
  end)
  run_cleanup_step(errors, 'workspace windows', function()
    window.restore_all_workspace_windows(instance)
  end)
  run_cleanup_step(errors, 'origin window options', function()
    if state.origin_win_options ~= nil then
      window_options.restore(state.origin_win_options)
      state.origin_win_options = nil
    end
  end)
  run_cleanup_step(errors, 'help window', function()
    close_help(instance)
  end)
  run_cleanup_step(errors, 'help buffer', function()
    delete_help_buffer(instance)
  end)
  run_cleanup_step(errors, 'autocmd group', function()
    if instance.group then
      local group = instance.group
      vim.api.nvim_del_augroup_by_id(group)
      if instance.group == group then
        instance.group = nil
        instance.autocmd_buf = nil
      end
    end
  end)
  run_cleanup_step(errors, 'debounce timer', function()
    timers.stop_debounce(instance)
  end)
  run_cleanup_step(errors, 'workspace buffer', function()
    if is_wiping_buffer(workspace_buf) then
      if state.buf == workspace_buf then
        state.buf = nil
        state.last_workspace_win = nil
      end
      return
    end

    if window.is_valid_buf(workspace_buf) then
      vim.api.nvim_buf_delete(workspace_buf, { force = true })
    end
    if state.buf == workspace_buf and not window.is_valid_buf(workspace_buf) then
      state.buf = nil
      state.last_workspace_win = nil
    end
  end)
  state.closing = false

  if notify_cleanup_errors('cleanup failed', errors) then
    instance.group = nil
    instance.autocmd_buf = nil
    ui_state.reset_workspace_handles(state)
    reset_view_state(state)
  end
end

--- Open the workspace in the current window, setting up buffer and initial render
--- @param instance table The Instance object holding UI state
--- @return nil
function M.open(instance)
  local state = instance_state(instance)
  assert_rerender(instance)
  assert_namespace(instance)
  assert_group_name(instance)
  local current_win = vim.api.nvim_get_current_win()
  local visible_win = window.get_win(instance)
  if visible_win ~= nil and visible_win ~= current_win then
    vim.api.nvim_set_current_win(visible_win)
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local open_snapshot = snapshot_open_state(instance, state, current_win, current_buf)
  local installed_preview_keymap = false
  local ok, err = xpcall(function()
    if current_buf ~= state.buf then
      state.origin_win = current_win
      state.origin_buf = current_buf
      state.origin_win_options = window_options.snapshot(current_win)
    end

    local buf = buffer.ensure(instance)
    vim.api.nvim_set_current_buf(buf)
    window.capture_workspace_window(instance, current_win)

    instance:rerender()
    if state.preview.keymap == nil then
      install_preview_keymap(instance)
      installed_preview_keymap = state.preview.keymap ~= nil
    end
    require('hlcraft.ui.input.buffer_fields').goto_first(instance)
    require('hlcraft.ui.navigation').clamp_cursor(instance)
  end, debug.traceback)
  if not ok then
    local rollback_errors = rollback_open(instance, state, open_snapshot, {
      installed_preview_keymap = installed_preview_keymap,
    })
    if #rollback_errors > 0 then
      err = ('%s; rollback errors: %s'):format(tostring(err), table.concat(rollback_errors, '; '))
    end
    error(err, 0)
  end
end

return M
