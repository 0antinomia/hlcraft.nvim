local h = require('tests.helpers')
local scope = 'hlcraft dynamic runtime'

local config = require('hlcraft.config')
local runtime = require('hlcraft.dynamic.runtime')

local runtime_dynamic = {
  fg = {
    version = 1,
    duration = 2000,
    loop = 'repeat',
    interpolation = 'linear',
    timeline = {
      { at = 0, color = '#000000' },
      { at = 1, color = '#ffffff' },
    },
  },
  bg = {
    version = 1,
    duration = 2000,
    loop = 'repeat',
    interpolation = 'linear',
    timeline = {
      { at = 0, color = 'base' },
    },
    transforms = {
      {
        type = 'brightness',
        interpolation = 'linear',
        timeline = {
          { at = 0, value = 0.75 },
          { at = 1, value = 0.75 },
        },
      },
    },
  },
}

config.setup({
  dynamic = {
    enabled = false,
    interval_ms = 80,
  },
})
vim.api.nvim_set_hl(0, 'HlcraftDynamicRuntime', { fg = '#111111', bg = '#808080' })
runtime.stop()
runtime.sync_group('HlcraftDynamicRuntime', { fg = '#111111', bg = '#808080' }, {
  dynamic = runtime_dynamic,
})
runtime.tick(500)
local disabled_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(disabled_spec.fg, tonumber('111111', 16), 'disabled runtime changed fg', scope)

config.setup({
  dynamic = {
    enabled = true,
    interval_ms = 80,
  },
})
runtime.sync_group('HlcraftDynamicRuntime', { fg = '#111111', bg = '#808080' }, {
  dynamic = runtime_dynamic,
})
runtime.tick(1000)
local enabled_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(enabled_spec.fg, tonumber('808080', 16), 'runtime did not use configured custom fg', scope)
local transform_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(transform_spec.bg, tonumber('606060', 16), 'runtime did not use configured custom bg transform', scope)

runtime.stop()
local stopped_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(stopped_spec.fg, tonumber('111111', 16), 'runtime stop did not restore fg', scope)
h.assert_equal(stopped_spec.bg, tonumber('808080', 16), 'runtime stop did not restore bg', scope)

config.setup({})

print('hlcraft dynamic runtime: OK')
