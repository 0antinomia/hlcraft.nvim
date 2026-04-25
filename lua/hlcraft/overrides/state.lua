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
  runtime = {},
  runtime_groups = {},
}

function M.deepcopy(value)
  return vim.deepcopy(value)
end

function M.rebuild_active()
  M.data.active = vim.tbl_deep_extend('force', M.deepcopy(M.data.preset), M.deepcopy(M.data.runtime))
end

function M.refresh_base_specs()
  M.data.base_specs = {}
end

function M.ensure_runtime_group(name)
  if M.data.runtime_groups[name] == nil or vim.trim(tostring(M.data.runtime_groups[name])) == '' then
    M.data.runtime_groups[name] = M.data.persisted_groups[name]
  end
end

function M.known_groups()
  local groups = {}

  for _, group_name in pairs(M.data.persisted_groups) do
    if type(group_name) == 'string' and vim.trim(group_name) ~= '' then
      groups[group_name] = true
    end
  end
  for _, group_name in pairs(M.data.runtime_groups) do
    if type(group_name) == 'string' and vim.trim(group_name) ~= '' then
      groups[group_name] = true
    end
  end

  local names = vim.tbl_keys(groups)
  table.sort(names)
  return names
end

function M.remove_empty_runtime_entry(name)
  if M.data.runtime[name] and next(M.data.runtime[name]) == nil then
    M.data.runtime[name] = nil
    M.data.runtime_groups[name] = nil
  end
end

return M
