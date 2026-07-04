local h = require('tests.helpers')
local scope = 'hlcraft ui keymaps'

local keymaps = require('hlcraft.ui.keymaps')

local buf = vim.api.nvim_create_buf(false, true)
keymaps.setup_workspace_keymaps({
  state = {},
}, buf)

local function mapping(mode, lhs)
  for _, item in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
    if item.lhs == lhs then
      return item
    end
  end
  return nil
end

local function assert_mapping(mode, lhs)
  local item = mapping(mode, lhs)
  h.assert_true(item ~= nil, ('missing %s mapping for %s'):format(mode, lhs), scope)
  return item
end

local function enabled(item, key)
  return item[key] == true or item[key] == 1
end

for _, lhs in ipairs({ '<Esc>', 'q', '?', 'j', 'k', 'gg', 'G', 'gr', 'r', 'g', '+', '-', 'i', 'e', 'a' }) do
  assert_mapping('n', lhs)
end

assert_mapping('x', 'p')
assert_mapping('x', 'P')
h.assert_true(not enabled(assert_mapping('n', 'g'), 'nowait'), 'g mapping must wait for gg/gr', scope)
h.assert_true(enabled(assert_mapping('n', '<CR>'), 'expr'), '<CR> mapping must stay expr', scope)
h.assert_true(#vim.api.nvim_buf_get_keymap(buf, 'i') >= 5, 'input boundary mappings were not installed', scope)

vim.api.nvim_buf_delete(buf, { force = true })

print('hlcraft ui keymaps: OK')
