local h = require('tests.helpers')
local scope = 'hlcraft dynamic'

local model = require('hlcraft.dynamic.model')
local effects = require('hlcraft.dynamic.effects')

local default_spec = model.default_spec()
h.assert_equal(default_spec.mode, 'rgb', 'default mode is wrong', scope)
h.assert_equal(default_spec.speed, 2000, 'default speed is wrong', scope)

local rgb_defaults = model.default_palette()
h.assert_equal(rgb_defaults[1], '#ff0000', 'default palette first color changed', scope)
h.assert_equal(rgb_defaults[2], '#00ff00', 'default palette second color changed', scope)
h.assert_equal(rgb_defaults[3], '#0000ff', 'default palette third color changed', scope)

local normalized_palette = model.normalize_palette({
  '#000000',
  'ffffff',
  'bad',
  'NONE',
})
h.assert_equal(#normalized_palette, 2, 'normalize_palette did not keep two valid colors', scope)
h.assert_equal(normalized_palette[1], '#000000', 'normalize_palette changed first color', scope)
h.assert_equal(normalized_palette[2], '#ffffff', 'normalize_palette did not normalize bare hex', scope)

local fallback_palette = model.normalize_palette({ 'bad', '#111111' })
h.assert_equal(#fallback_palette, 3, 'invalid short palette did not fall back to default', scope)
h.assert_equal(fallback_palette[1], '#ff0000', 'fallback palette first color is wrong', scope)

local non_string_fallback_palette = model.normalize_palette({ 123, true, '#111111' })
h.assert_equal(#non_string_fallback_palette, 3, 'non-string invalid palette did not fall back to default', scope)
h.assert_equal(non_string_fallback_palette[1], '#ff0000', 'non-string fallback palette first color is wrong', scope)

local breath_params = model.normalize_params('breath', {
  min = 1.2,
  max = -0.2,
  phase = 0.25,
  custom = 'kept',
})
h.assert_equal(breath_params.min, 0, 'breath min was not clamped after swap', scope)
h.assert_equal(breath_params.max, 1, 'breath max was not clamped after swap', scope)
h.assert_equal(breath_params.phase, 0.25, 'breath phase was not preserved', scope)
h.assert_equal(breath_params.custom, 'kept', 'unknown breath param was not preserved', scope)

local normalized = model.normalize_channel({ mode = 'breath', speed = 3000 })
h.assert_equal(normalized.mode, 'breath', 'breath mode did not normalize', scope)
h.assert_equal(normalized.speed, 3000, 'speed did not normalize', scope)

local normalized_rgb = model.normalize_channel({
  mode = 'rgb',
  speed = 2000,
  palette = { '#123456', '#abcdef' },
})
h.assert_equal(normalized_rgb.palette[1], '#123456', 'rgb palette was not normalized into channel spec', scope)
h.assert_equal(normalized_rgb.palette[2], '#abcdef', 'rgb palette second color was not normalized', scope)

local normalized_breath = model.normalize_channel({
  mode = 'breath',
  speed = 2000,
  params = { min = 0.2, max = 0.8 },
})
h.assert_equal(normalized_breath.params.min, 0.2, 'breath min did not normalize into channel spec', scope)
h.assert_equal(normalized_breath.params.max, 0.8, 'breath max did not normalize into channel spec', scope)

local fallback_speed = model.normalize_channel({ mode = 'rgb', speed = 'fast' })
h.assert_equal(fallback_speed.speed, 2000, 'invalid speed did not use default', scope)

local fallback_nan_speed = model.normalize_channel({ mode = 'rgb', speed = 0 / 0 })
h.assert_equal(fallback_nan_speed.speed, 2000, 'NaN speed did not use default', scope)

local unsupported = model.normalize_channel({ mode = 'sparkle', speed = 3000 })
h.assert_true(unsupported == nil, 'unsupported mode was accepted', scope)

local entry = model.inflate_entry({
  fg = '#101010',
  dyn_fg_mode = 'rgb',
  dyn_fg_speed = 1500,
  dyn_fg_params = '{"phase":0.25}',
  dyn_fg_palette = '["#000000","#ffffff"]',
  dyn_bg_mode = 'breath',
  dyn_bg_speed = 'bad',
  dyn_bg_params = 'not json',
  dyn_bg_palette = '"not a table"',
})
h.assert_equal(entry.dynamic.fg.mode, 'rgb', 'dyn_fg_mode did not inflate', scope)
h.assert_equal(entry.dynamic.fg.speed, 1500, 'dyn_fg_speed did not inflate', scope)
h.assert_equal(entry.dynamic.fg.params.phase, 0.25, 'dyn_fg_params did not inflate', scope)
h.assert_equal(entry.dynamic.fg.palette[1], '#000000', 'dyn_fg_palette did not inflate', scope)
h.assert_equal(entry.dynamic.fg.palette[2], '#ffffff', 'dyn_fg_palette second color did not inflate', scope)
h.assert_equal(entry.dynamic.bg.mode, 'breath', 'dyn_bg_mode did not inflate', scope)
h.assert_equal(entry.dynamic.bg.speed, 2000, 'invalid dyn_bg_speed did not default', scope)
h.assert_equal(entry.dynamic.bg.params.min, 0.45, 'invalid dyn_bg_params did not default min', scope)
h.assert_equal(entry.dynamic.bg.params.max, 1.0, 'invalid dyn_bg_params did not default max', scope)
h.assert_true(entry.dynamic.bg.palette == nil, 'non-table dyn_bg_palette was not ignored', scope)
h.assert_true(entry.dyn_fg_mode == nil, 'flat dyn key was not removed during inflate', scope)
h.assert_true(entry.dyn_fg_speed == nil, 'flat dyn speed key was not removed during inflate', scope)
h.assert_true(entry.dyn_fg_params == nil, 'flat dyn params key was not removed during inflate', scope)
h.assert_true(entry.dyn_fg_palette == nil, 'flat dyn palette key was not removed during inflate', scope)
h.assert_true(entry.dyn_bg_mode == nil, 'flat dyn bg mode key was not removed during inflate', scope)
h.assert_true(entry.dyn_bg_speed == nil, 'flat dyn bg speed key was not removed during inflate', scope)
h.assert_true(entry.dyn_bg_params == nil, 'flat dyn bg params key was not removed during inflate', scope)
h.assert_true(entry.dyn_bg_palette == nil, 'flat dyn bg palette key was not removed during inflate', scope)

local flat = model.flatten_entry({
  fg = '#101010',
  dynamic = {
    fg = {
      mode = 'rgb',
      speed = 1500,
      params = { phase = 0.25 },
      palette = { '#000000', '#ffffff' },
    },
    sp = { mode = 'breath', speed = 2500 },
  },
})
h.assert_equal(flat.dyn_fg_mode, 'rgb', 'dynamic fg mode did not flatten', scope)
h.assert_equal(flat.dyn_fg_speed, 1500, 'dynamic fg speed did not flatten', scope)
h.assert_true(type(flat.dyn_fg_params) == 'string', 'dynamic fg params did not flatten', scope)
h.assert_true(type(flat.dyn_fg_palette) == 'string', 'dynamic fg palette did not flatten', scope)
h.assert_equal(flat.dyn_sp_mode, 'breath', 'dynamic sp mode did not flatten', scope)
h.assert_equal(flat.dyn_sp_speed, 2500, 'dynamic sp speed did not flatten', scope)
h.assert_true(flat.dynamic == nil, 'runtime dynamic table leaked into flat entry', scope)

local flat_default_rgb = model.flatten_entry({
  dynamic = {
    fg = { mode = 'rgb', speed = 1500 },
  },
})
h.assert_true(flat_default_rgb.dyn_fg_palette == nil, 'default rgb palette should not flatten', scope)

local flat_custom_rgb = model.flatten_entry({
  dynamic = {
    fg = { mode = 'rgb', speed = 1500, palette = { '#000000', '#ffffff' } },
  },
})
h.assert_true(type(flat_custom_rgb.dyn_fg_palette) == 'string', 'custom rgb palette should flatten', scope)

local flat_round_trip = model.inflate_entry(flat)
h.assert_equal(flat_round_trip.dynamic.fg.params.phase, 0.25, 'flat dyn params did not round-trip', scope)
h.assert_equal(flat_round_trip.dynamic.fg.palette[2], '#ffffff', 'flat dyn palette did not round-trip', scope)

local stale_flat = model.flatten_entry({
  dyn_fg_params = '{"phase":0.25}',
  dyn_fg_palette = '["#000000"]',
  dynamic = {
    fg = { mode = 'rgb', speed = 1500, params = {}, palette = {} },
  },
})
h.assert_true(stale_flat.dyn_fg_params == nil, 'empty dynamic params did not clear stale flat key', scope)
h.assert_true(stale_flat.dyn_fg_palette == nil, 'default dynamic palette did not clear stale flat key', scope)

h.assert_equal(effects.rgb(0, 3000), '#ff0000', 'rgb start color is wrong', scope)
h.assert_equal(effects.rgb(1000, 3000), '#00ff00', 'rgb one-third color is wrong', scope)
h.assert_equal(effects.rgb(2000, 3000), '#0000ff', 'rgb two-third color is wrong', scope)
h.assert_equal(
  effects.compute({ mode = 'rgb', speed = 3000 }, '#111111', 1000),
  '#00ff00',
  'rgb compute dispatch is wrong',
  scope
)

local breath_low = effects.breath('#808080', 0, 2000)
local breath_high = effects.breath('#808080', 1000, 2000)
h.assert_true(breath_low ~= breath_high, 'breath color did not change over phase', scope)
h.assert_true(effects.breath('NONE', 1000, 2000) == nil, 'breath accepted NONE base color', scope)

h.assert_equal(
  effects.rgb(500, 2000, { '#000000', '#ffffff' }),
  '#808080',
  'custom two-color rgb palette did not interpolate halfway',
  scope
)
h.assert_equal(
  effects.rgb(1500, 2000, { '#000000', '#ffffff' }),
  '#808080',
  'custom two-color rgb palette did not interpolate closed loop',
  scope
)

local breath_low = effects.breath('#808080', 0, 2000, { min = 0.25, max = 0.75 })
local breath_high = effects.breath('#808080', 1000, 2000, { min = 0.25, max = 0.75 })
h.assert_equal(breath_low, '#202020', 'breath min parameter did not affect low point', scope)
h.assert_equal(breath_high, '#606060', 'breath max parameter did not affect high point', scope)

local computed_palette = effects.compute({
  mode = 'rgb',
  speed = 2000,
  palette = { '#000000', '#ffffff' },
}, '#123456', 500)
h.assert_equal(computed_palette, '#808080', 'compute did not pass palette to rgb effect', scope)

local computed_breath = effects.compute({
  mode = 'breath',
  speed = 2000,
  params = { min = 0.25, max = 0.75 },
}, '#808080', 1000)
h.assert_equal(computed_breath, '#606060', 'compute did not pass params to breath effect', scope)

local config = require('hlcraft.config')
local runtime = require('hlcraft.dynamic.runtime')

config.setup({
  dynamic = {
    enabled = false,
    interval_ms = 80,
  },
})
vim.api.nvim_set_hl(0, 'HlcraftDynamicRuntime', { fg = '#111111', bg = '#222222' })
runtime.stop()
runtime.sync_group('HlcraftDynamicRuntime', { fg = '#111111', bg = '#222222' }, {
  dynamic = {
    fg = { mode = 'rgb', speed = 3000 },
  },
})
runtime.tick(1000)
local disabled_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(disabled_spec.fg, tonumber('111111', 16), 'disabled dynamic runtime changed fg', scope)

config.setup({
  dynamic = {
    enabled = true,
    interval_ms = 80,
  },
})
runtime.sync_group('HlcraftDynamicRuntime', { fg = '#111111', bg = '#222222' }, {
  dynamic = {
    fg = { mode = 'rgb', speed = 3000 },
    bg = { mode = 'breath', speed = 3000 },
  },
})
runtime.tick(1000)
local enabled_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(enabled_spec.fg, tonumber('00ff00', 16), 'enabled rgb dynamic did not update fg', scope)
h.assert_true(enabled_spec.bg ~= tonumber('222222', 16), 'enabled breath dynamic did not update bg', scope)

vim.api.nvim_set_hl(0, 'HlcraftDynamicRuntimePalette', { fg = '#123456' })
runtime.sync_group('HlcraftDynamicRuntimePalette', { fg = '#123456' }, {
  dynamic = {
    fg = {
      mode = 'rgb',
      speed = 2000,
      palette = { '#000000', '#ffffff' },
    },
  },
})
runtime.tick(500)
local palette_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntimePalette', create = false })
h.assert_equal(palette_spec.fg, tonumber('808080', 16), 'runtime rgb dynamic did not use configured palette', scope)

vim.api.nvim_set_hl(0, 'HlcraftDynamicRuntimeBreathParams', { fg = '#808080' })
runtime.sync_group('HlcraftDynamicRuntimeBreathParams', { fg = '#808080' }, {
  dynamic = {
    fg = {
      mode = 'breath',
      speed = 2000,
      params = { min = 0.25, max = 0.75 },
    },
  },
})
runtime.tick(1000)
local breath_params_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntimeBreathParams', create = false })
h.assert_equal(
  breath_params_spec.fg,
  tonumber('606060', 16),
  'runtime breath dynamic did not use configured params',
  scope
)

vim.api.nvim_set_hl(0, 'HlcraftDynamicDisableRestore', { fg = '#333333' })
runtime.sync_group('HlcraftDynamicDisableRestore', { fg = '#333333' }, {
  dynamic = {
    fg = { mode = 'rgb', speed = 3000 },
  },
})
runtime.tick(1000)
local animated_disable_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicDisableRestore', create = false })
h.assert_equal(animated_disable_spec.fg, tonumber('00ff00', 16), 'disable regression setup did not animate fg', scope)
config.setup({
  dynamic = {
    enabled = false,
    interval_ms = 80,
  },
})
runtime.tick(2000)
local disabled_restore_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicDisableRestore', create = false })
h.assert_equal(disabled_restore_spec.fg, tonumber('333333', 16), 'disabling dynamic did not restore base fg', scope)
h.assert_equal(runtime.active_count(), 0, 'disabling dynamic left active runtime tasks', scope)

config.setup({
  dynamic = {
    enabled = true,
    interval_ms = 80,
  },
})
runtime.stop()
local stopped_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(stopped_spec.fg, tonumber('111111', 16), 'runtime stop did not restore fg', scope)
h.assert_equal(stopped_spec.bg, tonumber('222222', 16), 'runtime stop did not restore bg', scope)

config.setup({})

print('hlcraft dynamic: OK')
