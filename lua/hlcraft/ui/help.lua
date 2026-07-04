local M = {}

local help_model = require('hlcraft.ui.help_model')
local line_highlights = require('hlcraft.ui.render.line_highlights')
local theme = require('hlcraft.ui.theme')

local function is_valid_buf(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function is_valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function refresh_buffer(buf)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.lines())
  vim.bo[buf].modifiable = false
end

function M.lines()
  return help_model.lines(require('hlcraft.config').config.preview_key)
end

function M.ensure_buffer(instance)
  if is_valid_buf(instance.state.help_buf) then
    refresh_buffer(instance.state.help_buf)
    return instance.state.help_buf
  end

  local buf = vim.api.nvim_create_buf(false, true)
  instance.state.help_buf = buf
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  refresh_buffer(buf)
  vim.keymap.set('n', 'q', function()
    M.toggle(instance)
  end, { buffer = buf, silent = true })
  vim.keymap.set('n', '<Esc>', function()
    M.toggle(instance)
  end, { buffer = buf, silent = true })

  return buf
end

function M.is_open(instance)
  return is_valid_win(instance.state.help_win)
end

function M.close(instance)
  if is_valid_win(instance.state.help_win) then
    pcall(vim.api.nvim_win_close, instance.state.help_win, true)
  end
  instance.state.help_win = nil
end

function M.delete_buffer(instance)
  if is_valid_buf(instance.state.help_buf) then
    pcall(vim.api.nvim_buf_delete, instance.state.help_buf, { force = true })
  end
  instance.state.help_buf = nil
end

function M.toggle(instance)
  if M.is_open(instance) then
    M.close(instance)
    return
  end

  local buf = M.ensure_buffer(instance)
  local line_count = vim.api.nvim_buf_line_count(buf)
  local max_height = math.max(1, vim.o.lines - 4)
  local height = math.min(line_count, max_height)
  local max_line_width = 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
  end
  local width = math.min(math.max(38, max_line_width + 2), math.max(1, vim.o.columns - 4))
  instance.state.help_win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    width = width,
    height = height,
    row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    zindex = 80,
  })

  vim.wo[instance.state.help_win].wrap = false
  vim.wo[instance.state.help_win].cursorline = false
  vim.wo[instance.state.help_win].number = false
  vim.wo[instance.state.help_win].relativenumber = false
  theme.apply(instance.ns)
  vim.api.nvim_win_set_hl_ns(instance.state.help_win, instance.ns)
  vim.api.nvim_buf_clear_namespace(instance.state.help_buf, instance.ns, 0, -1)
  vim.api.nvim_buf_add_highlight(instance.state.help_buf, instance.ns, theme.groups.title, 0, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(instance.state.help_buf)
  for line_nr = 2, line_count - 1 do
    local line = vim.api.nvim_buf_get_lines(instance.state.help_buf, line_nr, line_nr + 1, false)[1]
    if line and line ~= '' then
      if help_model.is_item_line(line) then
        line_highlights.apply_hint_line(instance, line_nr, line, { buf = instance.state.help_buf })
      else
        vim.api.nvim_buf_add_highlight(instance.state.help_buf, instance.ns, theme.groups.section, line_nr, 0, -1)
      end
    end
  end
end

return M
