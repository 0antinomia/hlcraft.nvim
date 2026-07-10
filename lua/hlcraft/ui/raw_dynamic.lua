local dynamic_editor = require('hlcraft.ui.editor.dynamic')
local editor_context = require('hlcraft.ui.editor.context')
local json = require('hlcraft.ui.json')
local notify = require('hlcraft.notify')
local session = require('hlcraft.ui.session')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('raw dynamic editor requires an instance', 3)
  end
  return instance.state
end

local function raw_dynamic_state(state)
  local raw_state = state.raw_dynamic
  if raw_state ~= nil and type(raw_state) ~= 'table' then
    error('raw dynamic editor state must be a table', 3)
  end
  if raw_state ~= nil then
    if raw_state.buf ~= nil and type(raw_state.buf) ~= 'number' then
      error('raw dynamic editor buffer handle must be a number or nil', 3)
    end
    if raw_state.win ~= nil and type(raw_state.win) ~= 'number' then
      error('raw dynamic editor window handle must be a number or nil', 3)
    end
  end
  return raw_state
end

local function active_dynamic(result, field)
  local name = editor_context.result_name(result, 'raw dynamic editor')
  field = editor_context.field_key(field, 'raw dynamic editor')
  return session.dynamic_value(name, field)
end

local function buffer_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
end

local function popup_geometry(line_count)
  local columns = math.max(1, vim.o.columns)
  local lines = math.max(1, vim.o.lines)
  local max_width = math.max(1, columns - 2)
  local max_height = math.max(1, lines - 4)
  local desired_width = math.max(48, math.min(96, math.floor(columns * 0.7)))
  local desired_height = math.max(8, math.min(28, line_count + 2))
  local width = math.min(max_width, desired_width)
  local height = math.min(max_height, desired_height)
  local row = math.max(0, math.floor((lines - height - 2) / 2))
  local col = math.max(0, math.floor((columns - width - 2) / 2))
  return width, height, row, col
end

local function clear_state(instance, buf, win)
  local state = instance_state(instance)
  local raw_state = raw_dynamic_state(state)
  if raw_state and raw_state.buf == buf and raw_state.win == win then
    state.raw_dynamic = nil
  end
end

local function clear_closed_state(instance, buf, win)
  local state = instance_state(instance)
  local raw_state = raw_dynamic_state(state)
  if raw_state and raw_state.buf == buf and raw_state.win == win then
    if not window.is_valid_win(win) and not window.is_valid_buf(buf) then
      state.raw_dynamic = nil
    end
  end
end

local function append_rollback_errors(err, rollback_errors)
  if #rollback_errors == 0 then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, table.concat(rollback_errors, '; '))
end

local function cleanup_created(instance, buf, win)
  local errors = {}
  if window.is_valid_win(win) then
    local closed, close_err = pcall(vim.api.nvim_win_close, win, true)
    if not closed then
      errors[#errors + 1] = ('raw dynamic window: %s'):format(tostring(close_err))
    end
  end
  if window.is_valid_buf(buf) then
    local deleted, delete_err = pcall(vim.api.nvim_buf_delete, buf, { force = true })
    if not deleted then
      errors[#errors + 1] = ('raw dynamic buffer: %s'):format(tostring(delete_err))
    end
  end
  if buf ~= nil or win ~= nil then
    clear_closed_state(instance, buf, win)
  end
  return errors
end

local function register_cleanup(instance, buf, win)
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    once = true,
    callback = function()
      clear_state(instance, buf, win)
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function()
      clear_state(instance, buf, win)
    end,
  })
end

local function run_keymap_action(action)
  local ok, err = xpcall(action, debug.traceback)
  if not ok then
    notify.error(err)
  end
end

local function close_or_notify(instance)
  local closed, err = M.close(instance)
  if not closed then
    notify.error(('failed to close raw dynamic editor: %s'):format(tostring(err or 'resources remain open')))
    return false
  end
  return true
end

function M.close(instance)
  local state = instance_state(instance)
  local raw_state = raw_dynamic_state(state)
  if raw_state then
    local buf = raw_state.buf
    local win = raw_state.win
    local errors = {}
    if window.is_valid_win(raw_state.win) then
      local closed, close_err = pcall(vim.api.nvim_win_close, raw_state.win, true)
      if not closed then
        errors[#errors + 1] = ('window: %s'):format(tostring(close_err))
      end
    end
    if window.is_valid_buf(raw_state.buf) then
      local deleted, delete_err = pcall(vim.api.nvim_buf_delete, raw_state.buf, { force = true })
      if not deleted then
        errors[#errors + 1] = ('buffer: %s'):format(tostring(delete_err))
      end
    end
    clear_closed_state(instance, buf, win)
    if not window.is_valid_win(win) and not window.is_valid_buf(buf) then
      return true
    end
    if #errors == 0 then
      errors[#errors + 1] = 'resources remain open'
    end
    return false, table.concat(errors, '; ')
  end
  return true
end

function M.open(instance, result, field)
  local state = instance_state(instance)
  local dynamic = active_dynamic(result, field)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  local closed, close_err = M.close(instance)
  if not closed then
    error(('failed to close existing raw dynamic editor: %s'):format(tostring(close_err)), 2)
  end

  local text = json.format(dynamic)
  local lines = vim.split(text, '\n', { plain = true })
  local width, height, row, col = popup_geometry(#lines)
  local buf, win
  local ok, err = xpcall(function()
    buf = vim.api.nvim_create_buf(false, true)
    state.raw_dynamic = { buf = buf, win = nil }

    vim.bo[buf].filetype = 'json'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      style = 'minimal',
      border = 'single',
      title = ' Dynamic JSON ',
      width = width,
      height = height,
      row = row,
      col = col,
    })

    vim.wo[win].wrap = false
    state.raw_dynamic = { buf = buf, win = win }
    register_cleanup(instance, buf, win)

    vim.keymap.set('n', 'q', function()
      run_keymap_action(function()
        close_or_notify(instance)
      end)
    end, { buffer = buf, silent = true, nowait = true })

    vim.keymap.set('n', 'w', function()
      run_keymap_action(function()
        local ok, err = dynamic_editor.set_raw_json(instance, result, field, buffer_text(buf))
        if not ok then
          notify.error(err or 'Invalid dynamic JSON')
          return
        end
        close_or_notify(instance)
      end)
    end, { buffer = buf, silent = true, nowait = true })

    vim.keymap.set('n', '=', function()
      run_keymap_action(function()
        local decoded = json.decode_object(buffer_text(buf))
        if not decoded then
          notify.error('Invalid dynamic JSON')
          return
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(json.format(decoded), '\n', { plain = true }))
      end)
    end, { buffer = buf, silent = true, nowait = true })
  end, debug.traceback)
  if not ok then
    error(append_rollback_errors(err, cleanup_created(instance, buf, win)), 0)
  end

  return true, nil
end

return M
