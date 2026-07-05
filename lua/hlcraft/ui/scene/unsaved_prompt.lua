local notify = require('hlcraft.notify')
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
  if not numbers.is_finite(instance.ns) or math.floor(instance.ns) ~= instance.ns or instance.ns < 0 then
    error('unsaved prompt namespace must be a non-negative finite integer', 3)
  end
  return instance.ns
end

local function assert_name(name)
  if type(name) ~= 'string' or name == '' then
    error('unsaved prompt name must be a non-empty string', 3)
  end
  return name
end

local function assert_on_done(on_done)
  if type(on_done) ~= 'function' then
    error('unsaved prompt completion callback must be a function', 3)
  end
  return on_done
end

function M.close(instance)
  local state = instance_state(instance)
  local prompt = prompt_state(state)
  if window.is_valid_win(prompt.win) then
    pcall(vim.api.nvim_win_close, prompt.win, true)
  end
  if window.is_valid_buf(prompt.buf) then
    pcall(vim.api.nvim_buf_delete, prompt.buf, { force = true })
  end
  state.unsaved_prompt = { win = nil, buf = nil }
end

local function create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.lines)
  vim.bo[buf].modifiable = false
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

local function install_keymaps(instance, buf, name, on_done)
  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set('n', 's', function()
    local ok, err = session.save(instance, name)
    if ok then
      on_done()
    else
      notify.error(err)
    end
  end, opts)
  vim.keymap.set('n', 'd', function()
    session.discard(instance, name)
    on_done()
  end, opts)
  for _, key in ipairs({ 'c', 'q', '<Esc>' }) do
    vim.keymap.set('n', key, function()
      M.close(instance)
    end, opts)
  end
end

function M.open(instance, name, on_done)
  local state = instance_state(instance)
  prompt_state(state)
  local ns = prompt_namespace(instance)
  name = assert_name(name)
  on_done = assert_on_done(on_done)
  M.close(instance)

  local buf = create_buffer()
  local win = open_window(buf)

  state.unsaved_prompt = { win = win, buf = buf }
  apply_window_options(win)
  if ns ~= nil then
    apply_highlights(instance, buf, win)
  end
  install_keymaps(instance, buf, name, on_done)
end

return M
