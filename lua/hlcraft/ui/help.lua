local M = {}

local handles = require('hlcraft.ui.handles')
local help_model = require('hlcraft.ui.help_model')
local line_highlights = require('hlcraft.ui.render.line_highlights')
local notify = require('hlcraft.notify')
local numbers = require('hlcraft.core.number')
local theme = require('hlcraft.ui.theme')

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('help window requires an instance', 3)
  end
  return instance.state
end

local function instance_namespace(instance)
  if type(instance.ns) ~= 'number' then
    error('help window namespace must be a number', 3)
  end
  if not numbers.is_integer(instance.ns, 0) then
    error('help window namespace must be a non-negative finite integer', 3)
  end
  return instance.ns
end

local function append_rollback_errors(err, rollback_errors)
  if #rollback_errors == 0 then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, table.concat(rollback_errors, '; '))
end

local function refresh_buffer(buf)
  local previous_modifiable = vim.bo[buf].modifiable
  local previous_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local ok, err = xpcall(function()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.lines())
    vim.bo[buf].modifiable = false
  end, debug.traceback)
  if ok then
    return
  end

  local rollback_errors = {}
  local restored_lines, restore_lines_err = xpcall(function()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, previous_lines)
  end, debug.traceback)
  if not restored_lines then
    rollback_errors[#rollback_errors + 1] = tostring(restore_lines_err)
  end
  local restored_option, restore_option_err = xpcall(function()
    vim.bo[buf].modifiable = previous_modifiable
  end, debug.traceback)
  if not restored_option then
    rollback_errors[#rollback_errors + 1] = tostring(restore_option_err)
  end
  error(append_rollback_errors(err, rollback_errors), 0)
end

local function run_keymap_action(action)
  local ok, err = xpcall(action, debug.traceback)
  if not ok then
    notify.error(err)
  end
end

local function toggle_from_keymap(instance)
  run_keymap_action(function()
    local ok, err = M.toggle(instance)
    if ok == false then
      notify.error(('failed to close help window: %s'):format(tostring(err or 'window remains open')))
    end
  end)
end

function M.lines()
  return help_model.lines(require('hlcraft.config').config.keymaps.preview)
end

function M.ensure_buffer(instance)
  local state = instance_state(instance)
  if handles.is_valid_buf(state.help_buf) then
    refresh_buffer(state.help_buf)
    return state.help_buf
  end

  local buf
  local ok, err = xpcall(function()
    buf = vim.api.nvim_create_buf(false, true)
    state.help_buf = buf
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].swapfile = false
    refresh_buffer(buf)
    vim.keymap.set('n', 'q', function()
      toggle_from_keymap(instance)
    end, { buffer = buf, silent = true })
    vim.keymap.set('n', '<Esc>', function()
      toggle_from_keymap(instance)
    end, { buffer = buf, silent = true })
  end, debug.traceback)
  if not ok then
    local rollback_errors = {}
    if handles.is_valid_buf(buf) then
      local deleted, delete_err = pcall(vim.api.nvim_buf_delete, buf, { force = true })
      if not deleted then
        rollback_errors[#rollback_errors + 1] = ('help buffer: %s'):format(tostring(delete_err))
      end
    end
    if state.help_buf == buf and not handles.is_valid_buf(buf) then
      state.help_buf = nil
    end
    error(append_rollback_errors(err, rollback_errors), 0)
  end

  return buf
end

function M.is_open(instance)
  return handles.is_valid_win(instance_state(instance).help_win)
end

function M.close(instance)
  local state = instance_state(instance)
  local win = state.help_win
  local close_err
  if handles.is_valid_win(state.help_win) then
    local closed, err = pcall(vim.api.nvim_win_close, state.help_win, true)
    if not closed then
      close_err = err
    end
  end
  if not handles.is_valid_win(win) then
    state.help_win = nil
    return true
  end
  return false, tostring(close_err or 'help window remains open')
end

function M.delete_buffer(instance)
  local state = instance_state(instance)
  local buf = state.help_buf
  local delete_err
  if handles.is_valid_buf(state.help_buf) then
    local deleted, err = pcall(vim.api.nvim_buf_delete, state.help_buf, { force = true })
    if not deleted then
      delete_err = err
    end
  end
  if not handles.is_valid_buf(buf) then
    state.help_buf = nil
    return true
  end
  return false, tostring(delete_err or 'help buffer remains valid')
end

function M.toggle(instance)
  local state = instance_state(instance)
  if M.is_open(instance) then
    return M.close(instance)
  end

  local ns = instance_namespace(instance)
  local buf = M.ensure_buffer(instance)
  local line_count = vim.api.nvim_buf_line_count(buf)
  local max_height = math.max(1, vim.o.lines - 4)
  local height = math.min(line_count, max_height)
  local max_line_width = 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
  end
  local width = math.min(math.max(38, max_line_width + 2), math.max(1, vim.o.columns - 4))
  local win
  local ok, err = xpcall(function()
    win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      style = 'minimal',
      border = 'rounded',
      width = width,
      height = height,
      row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
      col = math.max(1, math.floor((vim.o.columns - width) / 2)),
      zindex = 80,
    })
    state.help_win = win

    vim.wo[win].wrap = false
    vim.wo[win].cursorline = false
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    theme.apply(ns)
    vim.api.nvim_win_set_hl_ns(win, ns)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns, theme.groups.title, 0, 0, -1)
    local buffer_line_count = vim.api.nvim_buf_line_count(buf)
    for line_nr = 2, buffer_line_count - 1 do
      local line = vim.api.nvim_buf_get_lines(buf, line_nr, line_nr + 1, false)[1]
      if line and line ~= '' then
        if help_model.is_item_line(line) then
          line_highlights.apply_hint_line(instance, line_nr, line, { buf = buf })
        else
          vim.api.nvim_buf_add_highlight(buf, ns, theme.groups.section, line_nr, 0, -1)
        end
      end
    end
  end, debug.traceback)
  if not ok then
    local rollback_errors = {}
    if handles.is_valid_win(win) then
      local closed, close_err = pcall(vim.api.nvim_win_close, win, true)
      if not closed then
        rollback_errors[#rollback_errors + 1] = ('help window: %s'):format(tostring(close_err))
      end
    end
    if state.help_win == win and not handles.is_valid_win(win) then
      state.help_win = nil
    end
    error(append_rollback_errors(err, rollback_errors), 0)
  end
end

return M
