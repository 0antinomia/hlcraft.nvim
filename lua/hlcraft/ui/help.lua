local M = {}

local function is_valid_buf(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function is_valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

function M.lines()
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

function M.ensure_buffer(instance)
  if is_valid_buf(instance.state.help_buf) then
    return instance.state.help_buf
  end

  local buf = vim.api.nvim_create_buf(false, true)
  instance.state.help_buf = buf
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.lines())
  vim.bo[buf].modifiable = false
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
  instance.state.help_win = vim.api.nvim_open_win(buf, true, {
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

return M
