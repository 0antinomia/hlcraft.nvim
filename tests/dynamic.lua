local h = require('tests.helpers')
local scope = 'hlcraft dynamic'

local config = require('hlcraft.config')
local effects = require('hlcraft.dynamic.effects')
local model = require('hlcraft.dynamic.model')
local runtime = require('hlcraft.dynamic.runtime')

local default_spec = model.default_spec()
h.assert_equal(default_spec.mode, 'rgb', 'default dynamic mode changed', scope)
h.assert_equal(default_spec.speed, 2000, 'default dynamic speed changed', scope)
h.assert_equal(default_spec.palette[1], '#ff0000', 'default palette first color changed', scope)
h.assert_equal(default_spec.palette[2], '#00ff00', 'default palette second color changed', scope)
h.assert_equal(default_spec.palette[3], '#0000ff', 'default palette third color changed', scope)

local normalized_palette = model.normalize_palette({ '#000000', 'ffffff', 'bad', 'NONE' })
h.assert_equal(#normalized_palette, 2, 'palette normalization kept wrong number of colors', scope)
h.assert_equal(normalized_palette[2], '#ffffff', 'bare hex palette color was not normalized', scope)

local fallback_palette = model.normalize_palette({ 123, '#111111' })
h.assert_equal(#fallback_palette, 3, 'short invalid palette did not fall back to defaults', scope)
h.assert_equal(fallback_palette[1], '#ff0000', 'fallback palette first color changed', scope)

local breath_params = model.normalize_params('breath', {
  min = 1.2,
  max = -0.2,
})
h.assert_equal(breath_params.min, 0, 'breath min was not clamped after swap', scope)
h.assert_equal(breath_params.max, 1, 'breath max was not clamped after swap', scope)

local normalized_channel = model.normalize_channel({
  mode = 'rgb',
  speed = 'bad',
  palette = { '#123456', '#abcdef' },
})
h.assert_equal(normalized_channel.speed, 2000, 'invalid speed did not use default', scope)
h.assert_equal(normalized_channel.palette[2], '#abcdef', 'rgb palette did not normalize into channel', scope)
h.assert_true(model.normalize_channel({ mode = 'sparkle' }) == nil, 'unsupported dynamic mode was accepted', scope)

local inflated = model.inflate_entry({
  fg = '#101010',
  dyn_fg_mode = 'rgb',
  dyn_fg_speed = 1500,
  dyn_fg_params = '{"phase":0.25}',
  dyn_fg_palette = '["#000000","#ffffff"]',
  dyn_bg_mode = 'breath',
  dyn_bg_params = '{"min":0.2,"max":0.8}',
})
h.assert_equal(inflated.dynamic.fg.mode, 'rgb', 'flat rgb dynamic mode did not inflate', scope)
h.assert_equal(inflated.dynamic.fg.speed, 1500, 'flat rgb dynamic speed did not inflate', scope)
h.assert_equal(inflated.dynamic.fg.params.phase, 0.25, 'flat rgb params did not inflate', scope)
h.assert_equal(inflated.dynamic.fg.palette[2], '#ffffff', 'flat rgb palette did not inflate', scope)
h.assert_equal(inflated.dynamic.bg.params.min, 0.2, 'flat breath min did not inflate', scope)
h.assert_true(inflated.dyn_fg_mode == nil, 'flat dynamic key leaked after inflate', scope)

local flattened = model.flatten_entry(inflated)
h.assert_equal(flattened.dyn_fg_mode, 'rgb', 'dynamic fg mode did not flatten', scope)
h.assert_equal(flattened.dyn_fg_speed, 1500, 'dynamic fg speed did not flatten', scope)
h.assert_equal(flattened.dyn_bg_mode, 'breath', 'dynamic bg mode did not flatten', scope)

local flat_default_rgb = model.flatten_entry({
  dynamic = {
    fg = { mode = 'rgb', speed = 1500 },
  },
})
h.assert_true(flat_default_rgb.dyn_fg_palette == nil, 'default rgb palette should be omitted on flatten', scope)

h.assert_equal(effects.rgb(1000, 3000), '#00ff00', 'default rgb effect sample changed', scope)
h.assert_equal(
  effects.rgb(500, 2000, { '#000000', '#ffffff' }),
  '#808080',
  'custom rgb palette did not interpolate',
  scope
)
h.assert_equal(
  effects.breath('#808080', 1000, 2000, { min = 0.25, max = 0.75 }),
  '#606060',
  'breath params did not affect brightness',
  scope
)
h.assert_equal(
  effects.compute({
    mode = 'rgb',
    speed = 2000,
    palette = { '#000000', '#ffffff' },
  }, '#123456', 500),
  '#808080',
  'compute did not dispatch rgb palette effect',
  scope
)

config.setup({
  dynamic = {
    enabled = false,
    interval_ms = 80,
  },
})
vim.api.nvim_set_hl(0, 'HlcraftDynamicRuntime', { fg = '#111111', bg = '#808080' })
runtime.stop()
runtime.sync_group('HlcraftDynamicRuntime', { fg = '#111111', bg = '#808080' }, {
  dynamic = {
    fg = { mode = 'rgb', speed = 2000, palette = { '#000000', '#ffffff' } },
    bg = { mode = 'breath', speed = 2000, params = { min = 0.25, max = 0.75 } },
  },
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
  dynamic = {
    fg = { mode = 'rgb', speed = 2000, palette = { '#000000', '#ffffff' } },
    bg = { mode = 'breath', speed = 2000, params = { min = 0.25, max = 0.75 } },
  },
})
runtime.tick(500)
local enabled_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(enabled_spec.fg, tonumber('808080', 16), 'runtime did not use configured rgb palette', scope)
runtime.tick(1000)
local breath_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(breath_spec.bg, tonumber('606060', 16), 'runtime did not use configured breath params', scope)

runtime.stop()
local stopped_spec = vim.api.nvim_get_hl(0, { name = 'HlcraftDynamicRuntime', create = false })
h.assert_equal(stopped_spec.fg, tonumber('111111', 16), 'runtime stop did not restore fg', scope)
h.assert_equal(stopped_spec.bg, tonumber('808080', 16), 'runtime stop did not restore bg', scope)

config.setup({})

print('hlcraft dynamic: OK')
