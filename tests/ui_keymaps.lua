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

  local original_keymap_set = vim.keymap.set
  local keymap_set_calls = 0
  vim.keymap.set = function(...)
    keymap_set_calls = keymap_set_calls + 1
    if keymap_set_calls == 2 then
      error('keymap failed')
    end
    return original_keymap_set(...)
  end
  local failed_setup_ok = pcall(keymaps.setup_workspace_keymaps, { state = {} }, buf)
  vim.keymap.set = original_keymap_set
  h.assert_true(not failed_setup_ok, 'workspace keymaps accepted failed install', scope)
  h.assert_equal(#vim.api.nvim_buf_get_keymap(buf, 'n'), 0, 'failed workspace keymap install leaked normal maps', scope)
  h.assert_equal(#vim.api.nvim_buf_get_keymap(buf, 'i'), 0, 'failed workspace keymap install leaked insert maps', scope)
  h.assert_equal(#vim.api.nvim_buf_get_keymap(buf, 'x'), 0, 'failed workspace keymap install leaked visual maps', scope)

  local original_keymap_del = vim.keymap.del
  keymap_set_calls = 0
  vim.keymap.set = function(...)
    keymap_set_calls = keymap_set_calls + 1
    if keymap_set_calls == 2 then
      error('keymap failed')
    end
    return original_keymap_set(...)
  end
  vim.keymap.del = function(mode, lhs, opts)
    if mode == 'n' and lhs == '<Esc>' and opts.buffer == buf then
      error('keymap cleanup failed')
    end
    return original_keymap_del(mode, lhs, opts)
  end
  local failed_cleanup_ok, failed_cleanup_err = pcall(keymaps.setup_workspace_keymaps, { state = {} }, buf)
  vim.keymap.set = original_keymap_set
  vim.keymap.del = original_keymap_del
  local leaked_mapping = false
  for _, item in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
    if item.lhs == '<Esc>' then
      leaked_mapping = true
      break
    end
  end
  if leaked_mapping then
    original_keymap_del('n', '<Esc>', { buffer = buf })
  end
  h.assert_true(not failed_cleanup_ok, 'workspace keymaps accepted failed install cleanup', scope)
  h.assert_true(leaked_mapping, 'keymap cleanup failure did not preserve its leaked mapping fixture', scope)
  h.assert_true(
    tostring(failed_cleanup_err):find('keymap cleanup failed', 1, true) ~= nil,
    'workspace keymap cleanup failure was not reported',
    scope
  )

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

  local keymap_notifications = {}
  local keymap_callback_ok = h.with_notify_stub(function()
    return pcall(assert_mapping('n', '?').callback)
  end, function(message)
    keymap_notifications[#keymap_notifications + 1] = message
  end)
  h.assert_true(keymap_callback_ok, 'workspace keymap callback error escaped', scope)
  h.assert_true(
    keymap_notifications[1] and keymap_notifications[1]:find('workspace keymap ? failed', 1, true) ~= nil,
    'workspace keymap callback error was not notified',
    scope
  )
end)

print('hlcraft ui keymaps: OK')
