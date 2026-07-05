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

function M.close(instance)
  local state = instance_state(instance)
  local raw_state = raw_dynamic_state(state)
  if raw_state then
    if window.is_valid_win(raw_state.win) then
      pcall(vim.api.nvim_win_close, raw_state.win, true)
    end
    if window.is_valid_buf(raw_state.buf) then
      pcall(vim.api.nvim_buf_delete, raw_state.buf, { force = true })
    end
  end
  state.raw_dynamic = nil
end

function M.open(instance, result, field)
  local state = instance_state(instance)
  local dynamic = active_dynamic(result, field)
  if not dynamic then
    return false, 'No dynamic color field is active'
  end

  M.close(instance)

  local text = json.format(dynamic)
  local lines = vim.split(text, '\n', { plain = true })
  local width, height, row, col = popup_geometry(#lines)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].filetype = 'json'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = vim.api.nvim_open_win(buf, true, {
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
    M.close(instance)
  end, { buffer = buf, silent = true, nowait = true })

  vim.keymap.set('n', 'w', function()
    local ok, err = dynamic_editor.set_raw_json(instance, result, field, buffer_text(buf))
    if not ok then
      notify.error(err or 'Invalid dynamic JSON')
      return
    end
    M.close(instance)
  end, { buffer = buf, silent = true, nowait = true })

  vim.keymap.set('n', '=', function()
    local decoded = json.decode_object(buffer_text(buf))
    if not decoded then
      notify.error('Invalid dynamic JSON')
      return
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(json.format(decoded), '\n', { plain = true }))
  end, { buffer = buf, silent = true, nowait = true })

  return true, nil
end

return M
