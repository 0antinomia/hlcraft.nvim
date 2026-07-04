local dynamic_editor = require('hlcraft.ui.editor.dynamic')
local json = require('hlcraft.ui.json')
local notify = require('hlcraft.notify')
local presets = require('hlcraft.dynamic.presets')
local session = require('hlcraft.ui.session')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function buffer_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
end

local function clear_state(instance, buf, win)
  if not instance or not instance.state then
    return
  end

  local state = instance.state.raw_dynamic
  if state and state.buf == buf and state.win == win then
    instance.state.raw_dynamic = nil
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
  local state = instance and instance.state and instance.state.raw_dynamic or {}
  if window.is_valid_win(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  if window.is_valid_buf(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  if instance and instance.state then
    instance.state.raw_dynamic = nil
  end
end

function M.open(instance, result, field)
  M.close(instance)

  local dynamic = session.dynamic_value(result.name, field) or presets.get('pulse')
  local text = json.format(dynamic)
  local lines = vim.split(text, '\n', { plain = true })
  local width = math.max(48, math.min(96, math.floor(vim.o.columns * 0.7)))
  local height = math.max(8, math.min(28, #lines + 2, vim.o.lines - 4))
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))
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
  instance.state.raw_dynamic = { buf = buf, win = win }
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
end

return M
