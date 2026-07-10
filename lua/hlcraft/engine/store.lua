local fields = require('hlcraft.core.fields')

local M = {}

M.style_keys = vim.deepcopy(fields.style_keys)
M.numeric_keys = vim.deepcopy(fields.numeric_keys)
M.override_keys = vim.deepcopy(fields.override_keys)
M.color_set = vim.deepcopy(fields.color_set)
M.style_set = vim.deepcopy(fields.style_set)

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

return M
