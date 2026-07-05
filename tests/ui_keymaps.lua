local h = require('tests.helpers')
local scope = 'hlcraft ui keymaps'

local keymaps = require('hlcraft.ui.keymaps')

local assert_fails = h.scoped_assert_fails(scope)

h.with_temp_buf(function(buf)
  assert_fails(function()
    keymaps.setup_workspace_keymaps(nil, buf)
  end, 'workspace keymaps accepted missing instance')
  assert_fails(function()
    keymaps.setup_workspace_keymaps({ state = {} }, nil)
  end, 'workspace keymaps accepted invalid buffer')

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
  for _, lhs in ipairs({ '<BS>', '<C-H>', '<C-W>', '<C-U>', '<Del>' }) do
    assert_mapping('i', lhs)
  end
  for _, lhs in ipairs({ 'X', 'S', 'D', 'c', 'C', 'I', 'A', 'O' }) do
    assert_mapping('n', lhs)
  end

  h.assert_true(not enabled(assert_mapping('n', 'g'), 'nowait'), 'g mapping must wait for gg/gr', scope)
  h.assert_true(enabled(assert_mapping('n', '<CR>'), 'expr'), '<CR> mapping must stay expr', scope)
end)

print('hlcraft ui keymaps: OK')
