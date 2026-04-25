local M = {}

M.managed = {
  'number',
  'relativenumber',
  'signcolumn',
  'foldcolumn',
}

M.workspace_values = {
  number = false,
  relativenumber = false,
  signcolumn = 'no',
  foldcolumn = '0',
}

function M.is_valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

function M.read(win)
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
  if not snapshot or not M.is_valid_win(snapshot.win) then
    return false
  end

  for option, value in pairs(snapshot.values or {}) do
    pcall(function()
      vim.wo[snapshot.win][option] = value
    end)
  end

  return true
end

function M.apply(win, ns)
  if ns ~= nil then
    vim.api.nvim_win_set_hl_ns(win, ns)
  end
  for option, value in pairs(M.workspace_values) do
    vim.wo[win][option] = value
  end
end

function M.matches_workspace(values)
  for option, expected in pairs(M.workspace_values) do
    if values[option] ~= expected then
      return false
    end
  end

  return true
end

return M
