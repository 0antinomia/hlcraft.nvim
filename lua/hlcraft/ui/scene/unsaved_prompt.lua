local notify = require('hlcraft.notify')
local highlight_names = require('hlcraft.core.highlight_names')
local line_highlights = require('hlcraft.ui.render.line_highlights')
local numbers = require('hlcraft.core.number')
local session = require('hlcraft.ui.session')
local theme = require('hlcraft.ui.theme')
local window = require('hlcraft.ui.workspace.window')

local M = {}

M.lines = {
  'Unsaved highlight changes',
  '',
  '[s] save draft',
  '[d] discard changes',
  '[c/q/Esc] cancel',
}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('unsaved prompt requires an instance', 3)
  end
  return instance.state
end

local function prompt_state(state)
  local prompt = state.unsaved_prompt
  if type(prompt) ~= 'table' then
    error('unsaved prompt state must be a table', 3)
  end
  return prompt
end

local function prompt_namespace(instance)
  if instance.ns == nil then
    return nil
  end
  if type(instance.ns) ~= 'number' then
    error('unsaved prompt namespace must be a number', 3)
  end
  if not numbers.is_integer(instance.ns, 0) then
    error('unsaved prompt namespace must be a non-negative finite integer', 3)
  end
  return instance.ns
end

local function assert_name(name)
  return highlight_names.assert(name, 'unsaved prompt name', 3)
end

local function assert_on_done(on_done)
  if type(on_done) ~= 'function' then
    error('unsaved prompt completion callback must be a function', 3)
  end
  return on_done
end

local function append_rollback_errors(err, rollback_errors)
  if #rollback_errors == 0 then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, table.concat(rollback_errors, '; '))
end

function M.close(instance)
  local state = instance_state(instance)
  local prompt = prompt_state(state)
  local buf = prompt.buf
  local win = prompt.win
  local errors = {}
  if window.is_valid_win(prompt.win) then
    local closed, close_err = pcall(vim.api.nvim_win_close, prompt.win, true)
    if not closed then
      errors[#errors + 1] = ('window: %s'):format(tostring(close_err))
    end
  end
  if window.is_valid_buf(prompt.buf) then
    local deleted, delete_err = pcall(vim.api.nvim_buf_delete, prompt.buf, { force = true })
    if not deleted then
      errors[#errors + 1] = ('buffer: %s'):format(tostring(delete_err))
    end
  end
  if not window.is_valid_win(win) and not window.is_valid_buf(buf) then
    state.unsaved_prompt = { win = nil, buf = nil }
    return true
  end
  if #errors == 0 then
    errors[#errors + 1] = 'resources remain open'
  end
  return false, table.concat(errors, '; ')
end

local function cleanup_created(instance, buf, win)
  local state = instance_state(instance)
  local prompt = prompt_state(state)
  local errors = {}
  if window.is_valid_win(win) then
    local closed, close_err = pcall(vim.api.nvim_win_close, win, true)
    if not closed then
      errors[#errors + 1] = ('unsaved prompt window: %s'):format(tostring(close_err))
    end
  end
  if window.is_valid_buf(buf) then
    local deleted, delete_err = pcall(vim.api.nvim_buf_delete, buf, { force = true })
    if not deleted then
      errors[#errors + 1] = ('unsaved prompt buffer: %s'):format(tostring(delete_err))
    end
  end
  if prompt.buf == buf and prompt.win == win then
    if not window.is_valid_win(win) and not window.is_valid_buf(buf) then
      state.unsaved_prompt = { win = nil, buf = nil }
    end
  end
  return errors
end

local function create_buffer(instance)
  local state = instance_state(instance)
  local buf
  local ok, err = xpcall(function()
    buf = vim.api.nvim_create_buf(false, true)
    state.unsaved_prompt = { win = nil, buf = buf }
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.lines)
    vim.bo[buf].modifiable = false
  end, debug.traceback)
  if not ok then
    error(append_rollback_errors(err, cleanup_created(instance, buf, nil)), 0)
  end
  return buf
end

local function max_line_width()
  local width = 0
  for _, line in ipairs(M.lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  return width
end

local function open_window(buf)
  local width = math.min(math.max(28, max_line_width() + 2), math.max(1, vim.o.columns - 4))
  local height = #M.lines
  return vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    width = width,
    height = height,
    row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    zindex = 90,
  })
end

local function apply_window_options(win)
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
end

local function apply_highlights(instance, buf, win)
  if instance.ns == nil then
    return
  end

  theme.apply(instance.ns)
  vim.api.nvim_win_set_hl_ns(win, instance.ns)
  vim.api.nvim_buf_clear_namespace(buf, instance.ns, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, instance.ns, theme.groups.title, 0, 0, -1)

  for line_nr = 2, #M.lines - 1 do
    local line = M.lines[line_nr + 1]
    if line and line ~= '' then
      line_highlights.apply_hint_line(instance, line_nr, line, { buf = buf })
    end
  end
end

local function run_keymap_action(action)
  local ok, err = xpcall(action, debug.traceback)
  if not ok then
    notify.error(err)
  end
end

local function install_keymaps(instance, buf, name, on_done)
  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set('n', 's', function()
    run_keymap_action(function()
      local ok, err = session.save(instance, name)
      if not ok then
        notify.error(err)
        if not session.is_dirty(name) then
          on_done()
        end
        return
      end
      on_done()
    end)
  end, opts)
  vim.keymap.set('n', 'd', function()
    run_keymap_action(function()
      local ok, err = session.discard(instance, name)
      if ok == false then
        notify.error(err)
        return
      end
      on_done()
    end)
  end, opts)
  for _, key in ipairs({ 'c', 'q', '<Esc>' }) do
    vim.keymap.set('n', key, function()
      run_keymap_action(function()
        local closed, close_err = M.close(instance)
        if not closed then
          notify.error(('failed to close unsaved prompt: %s'):format(tostring(close_err)))
        end
      end)
    end, opts)
  end
end

function M.open(instance, name, on_done)
  local state = instance_state(instance)
  prompt_state(state)
  local ns = prompt_namespace(instance)
  name = assert_name(name)
  on_done = assert_on_done(on_done)
  local closed, close_err = M.close(instance)
  if not closed then
    error(('failed to close existing unsaved prompt: %s'):format(tostring(close_err)), 2)
  end

  local buf, win
  local ok, err = xpcall(function()
    buf = create_buffer(instance)
    win = open_window(buf)

    state.unsaved_prompt = { win = win, buf = buf }
    apply_window_options(win)
    if ns ~= nil then
      apply_highlights(instance, buf, win)
    end
    install_keymaps(instance, buf, name, on_done)
  end, debug.traceback)
  if not ok then
    error(append_rollback_errors(err, cleanup_created(instance, buf, win)), 0)
  end
  return true, nil
end

return M
