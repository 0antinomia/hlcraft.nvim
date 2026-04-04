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

local function install_preview_keymap(instance)
  require('hlcraft.ui.preview').install_keymap(instance)
end

local function uninstall_preview_keymap(instance)
  require('hlcraft.ui.preview').uninstall_keymap(instance)
end

local function help_lines()
  local lines = {
    'hlcraft help',
    '',
    'Enter confirm / apply',
    'Move  cursor onto an input to edit',
    'q     back/close',
    'Esc   back/close',
    '?     toggle this help',
    'Tab   next input',
    'S-Tab prev input',
  }

  local preview_key = require('hlcraft.config').config.preview_key
  if preview_key and preview_key ~= false and preview_key ~= '' then
    table.insert(lines, 5, ('%s     flash current result'):format(preview_key))
  end

  return lines
end

--- Check if a buffer handle is valid
--- @param buf number|nil Buffer handle
--- @return boolean True if buffer is valid
function M.is_valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

--- Check if a window handle is valid
--- @param win number|nil Window handle
--- @return boolean True if window is valid
function M.is_valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

--- Get the workspace buffer handle
--- @param instance table The Instance object holding UI state
--- @return number|nil Buffer handle
function M.get_buf(instance)
  return instance.state.buf
end

--- Get the window displaying the workspace buffer
--- @param instance table The Instance object holding UI state
--- @return number|nil Window handle, or nil if buffer is not displayed
function M.get_win(instance)
  local buf = instance.state.buf
  if not M.is_valid_buf(buf) then
    return nil
  end
  local win = vim.fn.bufwinid(buf)
  return win ~= -1 and win or nil
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
function M.reset_view_state(instance)
  instance.state.results = {}
  instance.state.detail_index = nil
  instance.state.list_cursor = 1
  instance.state.name_query = ''
  instance.state.color_query = ''
  instance.state.geometry = {
    inputs = {},
    result_lines = {},
    detail_fields = {},
  }
  instance.state.detail_form = {}
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

--- Create the help buffer if it does not already exist
--- @param instance table The Instance object holding UI state
--- @return nil
function M.ensure_help_buffer(instance)
  if M.is_valid_buf(instance.state.help_buf) then
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  instance.state.help_buf = buf
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines())
  vim.bo[buf].modifiable = false
  vim.keymap.set('n', 'q', function()
    M.toggle_help(instance)
  end, { buffer = buf, silent = true })
  vim.keymap.set('n', '<Esc>', function()
    M.toggle_help(instance)
  end, { buffer = buf, silent = true })
end

--- Toggle the help floating window open or closed
--- @param instance table The Instance object holding UI state
--- @return nil
function M.toggle_help(instance)
  if M.is_valid_win(instance.state.help_win) then
    pcall(vim.api.nvim_win_close, instance.state.help_win, true)
    instance.state.help_win = nil
    return
  end

  M.ensure_help_buffer(instance)
  instance.state.help_win = vim.api.nvim_open_win(instance.state.help_buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    width = 38,
    height = 15,
    row = math.max(1, math.floor((vim.o.lines - 15) / 2) - 1),
    col = math.max(1, math.floor((vim.o.columns - 38) / 2)),
    zindex = 80,
  })

  vim.wo[instance.state.help_win].wrap = false
  vim.wo[instance.state.help_win].cursorline = false
  vim.wo[instance.state.help_win].number = false
  vim.wo[instance.state.help_win].relativenumber = false
  vim.api.nvim_win_set_hl_ns(instance.state.help_win, instance.ns)
  vim.api.nvim_buf_add_highlight(instance.state.help_buf, instance.ns, 'Title', 0, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(instance.state.help_buf)
  for line_nr = 2, line_count - 1 do
    local line = vim.api.nvim_buf_get_lines(instance.state.help_buf, line_nr, line_nr + 1, false)[1]
    if line and line ~= '' then
      local key = line:match('^(%S+)')
      if key then
        vim.api.nvim_buf_add_highlight(instance.state.help_buf, instance.ns, 'Function', line_nr, 0, #key)
      end
    end
  end
end

--- Create the workspace buffer if it does not already exist
--- @param instance table The Instance object holding UI state
--- @return number Buffer handle
function M.ensure_buffer(instance)
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
function M.apply_window_options(instance, win)
  vim.api.nvim_win_set_hl_ns(win, instance.ns)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  vim.wo[win].spell = false
  vim.wo[win].list = false
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].winbar = ''
end

--- Restore the origin buffer and window that was active before opening
--- @param instance table The Instance object holding UI state
--- @return nil
function M.restore_origin(instance)
  local win = M.get_win(instance)
  if not M.is_valid_win(win) then
    return
  end

  if
    M.is_valid_win(instance.state.origin_win)
    and M.is_valid_buf(instance.state.origin_buf)
    and instance.state.origin_buf ~= instance.state.buf
  then
    if win == instance.state.origin_win then
      pcall(vim.api.nvim_win_set_buf, win, instance.state.origin_buf)
    else
      pcall(vim.api.nvim_set_current_win, instance.state.origin_win)
      pcall(vim.api.nvim_win_set_buf, instance.state.origin_win, instance.state.origin_buf)
      if M.is_valid_win(win) then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
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
    cleanup_preview(instance)
    uninstall_preview_keymap(instance)
    if M.is_valid_win(instance.state.help_win) then
      pcall(vim.api.nvim_win_close, instance.state.help_win, true)
    end
    instance.state.help_win = nil
    M.restore_origin(instance)
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
    cleanup_preview(instance)
    uninstall_preview_keymap(instance)
    if M.is_valid_win(instance.state.help_win) then
      pcall(vim.api.nvim_win_close, instance.state.help_win, true)
    end
    if M.is_valid_buf(instance.state.help_buf) then
      pcall(vim.api.nvim_buf_delete, instance.state.help_buf, { force = true })
    end

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
  end)
  instance.state.closing = false
  if not ok then
    vim.notify(('hlcraft: cleanup failed: %s'):format(tostring(err)), vim.log.levels.WARN)
  end

  M.reset_view_state(instance)
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
  end

  local buf = M.ensure_buffer(instance)
  vim.api.nvim_set_current_buf(buf)

  local win = M.get_win(instance)
  if M.is_valid_win(win) then
    M.apply_window_options(instance, win)
  end

  instance:rerender()
  install_preview_keymap(instance)
  require('hlcraft.ui.input.actions').goto_first_input(instance)
  require('hlcraft.ui.navigation').clamp_cursor(instance)
end

return M
