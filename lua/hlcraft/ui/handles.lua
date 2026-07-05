local M = {}

function M.is_valid_buf(buf)
  return type(buf) == 'number' and vim.api.nvim_buf_is_valid(buf)
end

function M.is_valid_win(win)
  return type(win) == 'number' and vim.api.nvim_win_is_valid(win)
end

return M
