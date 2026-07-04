local M = {}

function M.is_valid_buf(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

function M.is_valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

return M
