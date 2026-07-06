local h = require('tests.helpers')
local scope = 'hlcraft ui preview'

local config = require('hlcraft.config')
local preview = require('hlcraft.ui.preview')
local ui_state = require('hlcraft.ui.state')

local lhs = '<Plug>(HlcraftPreviewTest)'
pcall(vim.keymap.del, 'n', lhs)

local assert_fails = h.scoped_assert_fails(scope)

local ok, err = xpcall(function()
  assert_fails(function()
    preview.install_keymap(nil)
  end, 'preview keymap install accepted missing instance')
  assert_fails(function()
    preview.cleanup({
      state = {
        preview = false,
      },
    })
  end, 'preview cleanup accepted invalid preview state')
  assert_fails(function()
    preview.flash_current({
      state = {
        preview = ui_state.preview(),
      },
    })
  end, 'preview flash accepted missing results')
  assert_fails(function()
    preview.flash_current({
      state = {
        preview = ui_state.preview(),
        results = {
          [2] = { name = 'Late' },
        },
        list_cursor = 2,
      },
    })
  end, 'preview flash accepted sparse results')
  assert_fails(function()
    preview.flash_current({
      state = {
        preview = ui_state.preview(),
        results = {
          { name = 'Normal' },
        },
        detail_index = 0,
      },
    })
  end, 'preview flash accepted invalid detail index')
  assert_fails(function()
    preview.flash_current({
      state = {
        preview = ui_state.preview(),
        results = {
          { name = 'Normal' },
        },
        list_cursor = 0,
      },
    })
  end, 'preview flash accepted invalid list cursor')
  assert_fails(function()
    preview.uninstall_keymap({
      state = {
        preview = {
          keymap = false,
        },
      },
    })
  end, 'preview keymap uninstall accepted invalid keymap state')
  assert_fails(function()
    preview.uninstall_keymap({
      state = {
        preview = {
          keymap = {},
        },
      },
    })
  end, 'preview keymap uninstall accepted missing lhs')

  local original_config = config.config
  config.config = vim.tbl_deep_extend('force', vim.deepcopy(original_config), {
    keymaps = {
      preview = true,
    },
  })
  assert_fails(function()
    preview.install_keymap({
      state = {
        preview = ui_state.preview(),
      },
    })
  end, 'preview keymap install accepted invalid preview key')
  config.config = vim.tbl_deep_extend('force', vim.deepcopy(original_config), {
    keymaps = {
      preview = {
        lhs = '   ',
      },
    },
  })
  assert_fails(function()
    preview.install_keymap({
      state = {
        preview = ui_state.preview(),
      },
    })
  end, 'preview keymap install accepted blank preview key')
  config.config = original_config

  vim.keymap.set('n', lhs, '<Nop>', {
    silent = true,
    desc = 'original preview test mapping',
  })

  config.setup({
    keymaps = {
      preview = {
        lhs = lhs,
        mode = 'n',
        opts = {
          desc = 'custom hlcraft preview',
          silent = true,
          nowait = true,
        },
      },
    },
  })

  local instance = {
    state = {
      preview = ui_state.preview(),
      results = {},
    },
  }

  preview.install_keymap(instance)
  local installed = vim.fn.maparg(lhs, 'n', false, true)
  h.assert_equal(installed.desc, 'custom hlcraft preview', 'preview mapping did not use configured opts', scope)

  preview.uninstall_keymap(instance)
  local restored = vim.fn.maparg(lhs, 'n', false, true)
  h.assert_equal(restored.desc, 'original preview test mapping', 'preview mapping description was not restored', scope)
  h.assert_equal(restored.rhs, '<Nop>', 'preview mapping rhs was not restored', scope)
  h.assert_true(instance.state.preview.keymap == nil, 'preview keymap state was not cleared', scope)

  local preview_name = 'HlcraftUiPreviewFlash'
  vim.api.nvim_set_hl(0, preview_name, { fg = '#111111' })
  local flash_instance = {
    state = {
      preview = ui_state.preview(),
      results = {
        { name = preview_name },
      },
      list_cursor = 1,
    },
  }
  preview.flash_current(flash_instance)
  local flashed = vim.api.nvim_get_hl(0, { name = preview_name })
  h.assert_equal(flashed.fg, 0x00e5ff, 'preview flash did not apply highlight color', scope)
  preview.cleanup(flash_instance)
  local restored_hl = vim.api.nvim_get_hl(0, { name = preview_name })
  h.assert_equal(restored_hl.fg, 0x111111, 'preview cleanup did not restore highlight color', scope)
end, debug.traceback)

pcall(vim.keymap.del, 'n', lhs)
config.setup({})

if not ok then
  error(err, 0)
end

print('hlcraft ui preview: OK')
