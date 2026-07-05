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
local bad_name_ok = pcall(runtime.sync_group, nil, { fg = '#111111' }, { dynamic = runtime_dynamic })
h.assert_true(not bad_name_ok, 'runtime accepted nil group name', scope)
local bad_base_spec_ok = pcall(runtime.sync_group, 'HlcraftDynamicRuntime', nil, { dynamic = runtime_dynamic })
h.assert_true(not bad_base_spec_ok, 'runtime accepted nil base spec', scope)
local bad_entry_ok = pcall(runtime.sync_group, 'HlcraftDynamicRuntime', { fg = '#111111' }, nil)
h.assert_true(not bad_entry_ok, 'runtime accepted nil entry', scope)
local bad_dynamic_ok = pcall(runtime.sync_group, 'HlcraftDynamicRuntime', { fg = '#111111' }, {
  dynamic = {
    fg = {
      version = 1,
      timeline = {},
    },
  },
})
h.assert_true(not bad_dynamic_ok, 'runtime accepted invalid dynamic override', scope)
local bad_clear_spec_ok = pcall(runtime.clear_group, 'HlcraftDynamicRuntime', 'bad-spec')
h.assert_true(not bad_clear_spec_ok, 'runtime accepted invalid restore spec', scope)
local bad_base_name_ok = pcall(runtime.base_spec, nil)
h.assert_true(not bad_base_name_ok, 'runtime base_spec accepted nil group name', scope)
runtime.sync_group('HlcraftDynamicRuntime', { fg = '#111111', bg = '#808080' }, {
  dynamic = runtime_dynamic,
})
h.assert_equal(runtime.active_count(), 0, 'disabled runtime registered a dynamic task', scope)
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
h.assert_equal(runtime.active_count(), 1, 'enabled runtime did not register a dynamic task', scope)
runtime.tick(1000)
local enabled_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(enabled_spec.fg, tonumber('808080', 16), 'runtime did not use configured custom fg', scope)
local transform_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(transform_spec.bg, tonumber('606060', 16), 'runtime did not use configured custom bg transform', scope)

runtime.stop()
h.assert_equal(runtime.active_count(), 0, 'runtime stop did not clear dynamic tasks', scope)
local stopped_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(stopped_spec.fg, tonumber('111111', 16), 'runtime stop did not restore fg', scope)
h.assert_equal(stopped_spec.bg, tonumber('808080', 16), 'runtime stop did not restore bg', scope)

config.setup({})

print('hlcraft dynamic runtime: OK')
