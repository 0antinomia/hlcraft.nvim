local M = {}

local handles = require('hlcraft.ui.handles')
local numbers = require('hlcraft.core.number')

M.managed = {
  'number',
  'relativenumber',
  'signcolumn',
  'foldcolumn',
}

local managed_set = {}
for _, option in ipairs(M.managed) do
  managed_set[option] = true
end

M.workspace_values = {
  number = false,
  relativenumber = false,
  signcolumn = 'no',
  foldcolumn = '0',
}

function M.is_valid_win(win)
  return handles.is_valid_win(win)
end

local function assert_win(win, label)
  if not M.is_valid_win(win) then
    error(('%s requires a valid window'):format(label), 3)
  end
  return win
end

local function assert_namespace(ns)
  if ns == nil then
    return nil
  end
  if type(ns) ~= 'number' then
    error('window option namespace must be a number', 3)
  end
  if not numbers.is_finite(ns) or math.floor(ns) ~= ns or ns < 0 then
    error('window option namespace must be a non-negative finite integer', 3)
  end
  return ns
end

function M.read(win)
  win = assert_win(win, 'window option read')
  local values = {}
  for _, option in ipairs(M.managed) do
    values[option] = vim.wo[win][option]
  end
  return values
end

function M.snapshot(win)
  if not M.is_valid_win(win) then
    return nil
  end

  return {
    win = win,
    values = M.read(win),
  }
end

function M.restore(snapshot)
  if snapshot == nil then
    return false
  end
  if type(snapshot) ~= 'table' then
    error('window option snapshot must be a table', 2)
  end
  if not M.is_valid_win(snapshot.win) then
    return false
  end

  if type(snapshot.values) ~= 'table' then
    error('window option snapshot values must be a table', 2)
  end

  for option, value in pairs(snapshot.values) do
    if not managed_set[option] then
      error(('window option snapshot contains unmanaged option: %s'):format(tostring(option)), 2)
    end
    pcall(function()
      vim.wo[snapshot.win][option] = value
    end)
  end

  return true
end

function M.apply(win, ns)
  win = assert_win(win, 'window option apply')
  ns = assert_namespace(ns)
  if ns ~= nil then
    vim.api.nvim_win_set_hl_ns(win, ns)
  end
  for option, value in pairs(M.workspace_values) do
    vim.wo[win][option] = value
  end
end

function M.matches_workspace(values)
  if type(values) ~= 'table' then
    error('window option values must be a table', 2)
  end

  for option, expected in pairs(M.workspace_values) do
    if values[option] ~= expected then
      return false
    end
  end

  return true
end

return M
