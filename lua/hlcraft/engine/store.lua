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

M.data = {
  applying = false,
  bootstrapped = false,
  group = nil,
  base_specs = {},
  active = {},
  preset = {},
  hooked = false,
  original_set_hl = vim.api.nvim_set_hl,
  persisted = {},
  persisted_groups = {},
  pending = {},
  draft = {},
  draft_groups = {},
}

M.data.runtime = M.data.draft
M.data.runtime_groups = M.data.draft_groups

return M
