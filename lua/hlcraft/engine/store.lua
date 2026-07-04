local fields = require('hlcraft.core.fields')

local M = {}

M.color_keys = vim.deepcopy(fields.color_keys)
M.style_keys = vim.deepcopy(fields.style_keys)
M.numeric_keys = vim.deepcopy(fields.numeric_keys)
M.override_keys = vim.deepcopy(fields.override_keys)

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
