local h = require('tests.helpers')
local scope = 'hlcraft ui preview'

local config = require('hlcraft.config')
local preview = require('hlcraft.ui.preview')
local ui_state = require('hlcraft.ui.state')

local lhs = '<Plug>(HlcraftPreviewTest)'
pcall(vim.keymap.del, 'n', lhs)

vim.keymap.set('n', lhs, '<Nop>', {
  silent = true,
  desc = 'original preview test mapping',
})

config.setup({
  preview_key = lhs,
})

local instance = {
  state = {
    preview = ui_state.preview(),
    results = {},
  },
}

preview.install_keymap(instance)
local installed = vim.fn.maparg(lhs, 'n', false, true)
h.assert_equal(installed.desc, 'hlcraft flash current highlight', 'preview mapping was not installed', scope)

preview.uninstall_keymap(instance)
local restored = vim.fn.maparg(lhs, 'n', false, true)
h.assert_equal(restored.desc, 'original preview test mapping', 'preview mapping description was not restored', scope)
h.assert_equal(restored.rhs, '<Nop>', 'preview mapping rhs was not restored', scope)
h.assert_true(instance.state.preview.keymap == nil, 'preview keymap state was not cleared', scope)

pcall(vim.keymap.del, 'n', lhs)
config.setup({})

print('hlcraft ui preview: OK')
