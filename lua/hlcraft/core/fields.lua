local M = {}

M.color_keys = { 'fg', 'bg', 'sp' }
M.style_keys = {
  'bold',
  'italic',
  'underline',
  'undercurl',
  'strikethrough',
  'underdouble',
  'underdotted',
  'underdashed',
}
M.numeric_keys = { 'blend' }
M.override_keys =
  vim.list_extend(vim.list_extend(vim.deepcopy(M.color_keys), vim.deepcopy(M.style_keys)), M.numeric_keys)

M.override_set = {}
for _, key in ipairs(M.override_keys) do
  M.override_set[key] = true
end

return M
