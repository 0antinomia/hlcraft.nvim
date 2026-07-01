local h = require('tests.helpers')
local scope = 'hlcraft dynamic'

local config = require('hlcraft.config')
local effects = require('hlcraft.dynamic.effects')
local model = require('hlcraft.dynamic.model')
local presets = require('hlcraft.dynamic.presets')
local runtime = require('hlcraft.dynamic.runtime')
local timeline = require('hlcraft.dynamic.timeline')
local transforms = require('hlcraft.dynamic.transforms')

local default_spec = model.default_spec('pulse')
h.assert_equal(default_spec.version, 1, 'default dynamic version changed', scope)
h.assert_equal(default_spec.preset, 'pulse', 'default dynamic preset changed', scope)
h.assert_equal(default_spec.duration, 2000, 'default dynamic duration changed', scope)
h.assert_equal(default_spec.loop, 'pingpong', 'default dynamic loop changed', scope)
h.assert_equal(default_spec.timeline[1].color, 'base', 'default dynamic first color changed', scope)
h.assert_equal(default_spec.timeline[2].color, '#ff6699', 'default dynamic second color changed', scope)

h.assert_true(model.mode_set == nil, 'old effect mode set should be removed', scope)
h.assert_true(model.default_rgb_palette == nil, 'old rgb palette default should be removed', scope)
h.assert_true(model.default_breath_params == nil, 'old breath params default should be removed', scope)

local normalized_custom = model.normalize_channel({
  version = 1,
  preset = 'manual',
  duration = 1750,
  loop = 'repeat',
  phase = 0.25,
  interpolation = 'smooth',
  timeline = {
    { at = 1, color = '#ffffff' },
    { at = 0, color = 'base' },
    { at = 0.5, color = 'fg' },
  },
  transforms = {
    {
      type = 'brightness',
      interpolation = 'linear',
      timeline = {
        { at = 0, value = 0.5 },
        { at = 1, value = 1.25 },
      },
    },
  },
})
h.assert_equal(normalized_custom.version, 1, 'custom version did not normalize', scope)
h.assert_equal(normalized_custom.duration, 1750, 'custom duration did not normalize', scope)
h.assert_equal(normalized_custom.loop, 'repeat', 'custom loop did not normalize', scope)
h.assert_equal(normalized_custom.phase, 0.25, 'custom phase did not normalize', scope)
h.assert_equal(normalized_custom.timeline[1].at, 0, 'timeline was not sorted', scope)
h.assert_equal(normalized_custom.timeline[2].color, 'fg', 'color reference did not normalize', scope)
h.assert_equal(normalized_custom.transforms[1].type, 'brightness', 'transform type did not normalize', scope)

local normalized_smoothstep = model.normalize_channel({
  version = 1,
  interpolation = 'smoothstep',
  timeline = {
    { at = 0, color = 'base' },
    { at = 1, color = '#ffffff' },
  },
})
h.assert_true(normalized_smoothstep ~= nil, 'smoothstep interpolation was rejected', scope)
h.assert_equal(normalized_smoothstep.interpolation, 'smoothstep', 'smoothstep interpolation did not normalize', scope)

h.assert_true(
  model.normalize_channel({ version = 2, timeline = { { at = 0, color = 'base' } } }) == nil,
  'unsupported version was accepted',
  scope
)
h.assert_true(model.normalize_channel({ version = 1, timeline = {} }) == nil, 'empty timeline was accepted', scope)
h.assert_true(
  model.normalize_channel({ version = 1, timeline = { { at = 0, color = 'bad-color' } } }) == nil,
  'invalid color reference was accepted',
  scope
)
h.assert_true(
  model.normalize_channel({ version = 1, timeline = { { color = 'base' } } }) == nil,
  'missing color stop at was accepted',
  scope
)
h.assert_true(
  model.normalize_channel({ version = 1, timeline = { { at = 'bad', color = 'base' } } }) == nil,
  'invalid color stop at was accepted',
  scope
)
h.assert_true(model.normalize_channel({
  version = 1,
  timeline = { { at = 0, color = 'base' } },
  transforms = {
    {
      type = 'brightness',
      timeline = {
        { value = 1 },
      },
    },
  },
}) == nil, 'missing transform stop at was accepted', scope)
h.assert_true(model.normalize_channel({
  version = 1,
  timeline = { { at = 0, color = 'base' } },
  transforms = {
    {
      type = 'brightness',
      timeline = {
        { at = 'bad', value = 1 },
      },
    },
  },
}) == nil, 'invalid transform stop at was accepted', scope)
h.assert_true(model.normalize_channel({ mode = 'rgb', speed = 1000 }) == nil, 'old rgb mode was accepted', scope)
h.assert_true(model.normalize_channel({ mode = 'breath', speed = 1000 }) == nil, 'old breath mode was accepted', scope)

local encoded_fg = vim.json.encode({
  version = 1,
  preset = 'pulse',
  duration = 1500,
  loop = 'pingpong',
  timeline = {
    { at = 0, color = 'base' },
    { at = 1, color = '#ffffff' },
  },
})
local inflated = model.inflate_entry({
  fg = '#101010',
  dyn_fg = encoded_fg,
  dyn_fg_mode = 'rgb',
  dyn_fg_speed = 1000,
})
h.assert_equal(inflated.dynamic.fg.preset, 'pulse', 'dyn_fg JSON did not inflate', scope)
h.assert_equal(inflated.dynamic.fg.duration, 1500, 'dyn_fg duration did not inflate', scope)
h.assert_true(inflated.dyn_fg == nil, 'dyn_fg key leaked after inflate', scope)
h.assert_true(inflated.dyn_fg_mode == nil, 'old flat key leaked after inflate', scope)
h.assert_true(inflated.dynamic.bg == nil, 'old effect mode key created bg dynamic config', scope)

local flattened = model.flatten_entry(inflated)
h.assert_true(type(flattened.dyn_fg) == 'string', 'dynamic fg did not flatten to JSON', scope)
h.assert_true(flattened.dyn_fg_mode == nil, 'old effect mode key was written', scope)
h.assert_true(flattened.dyn_fg_speed == nil, 'old effect timing key was written', scope)
local decoded_flat = vim.json.decode(flattened.dyn_fg)
h.assert_equal(decoded_flat.preset, 'pulse', 'flattened preset changed', scope)
h.assert_equal(decoded_flat.duration, 1500, 'flattened duration changed', scope)

for _, preset_name in ipairs({ 'pulse', 'breath', 'hue', 'gradient', 'blink', 'duotone' }) do
  local preset = presets.get(preset_name)
  h.assert_equal(preset.version, 1, ('preset %s version changed'):format(preset_name), scope)
  h.assert_equal(preset.preset, preset_name, ('preset %s label changed'):format(preset_name), scope)
  h.assert_true(model.normalize_channel(preset) ~= nil, ('preset %s did not normalize'):format(preset_name), scope)
end

local fallback_preset = presets.get('unknown')
h.assert_equal(fallback_preset.preset, 'pulse', 'unknown preset did not fall back to pulse', scope)

local numeric_stops = {
  { at = 0, value = 0 },
  { at = 1, value = 10 },
}
h.assert_equal(timeline.sample_numeric(numeric_stops, 0.5, 'linear'), 5, 'linear numeric sample changed', scope)
h.assert_equal(timeline.sample_numeric(numeric_stops, 0.5, 'step'), 0, 'step numeric sample changed', scope)
h.assert_equal(
  timeline.sample_numeric({ { at = 0, value = 0 }, { at = 1, value = 1 } }, 0.25, 'smoothstep'),
  0.15625,
  'smoothstep numeric sample changed',
  scope
)
h.assert_equal(timeline.phase(250, 1000, 0, 'repeat'), 0.25, 'repeat phase changed', scope)
h.assert_equal(timeline.phase(1250, 1000, 0, 'repeat'), 0.25, 'repeat wrapped phase changed', scope)
h.assert_equal(timeline.phase(1250, 1000, 0, 'pingpong'), 0.75, 'pingpong phase changed', scope)
h.assert_equal(timeline.phase(1250, 1000, 0, 'once'), 1, 'once phase changed', scope)
h.assert_equal(timeline.phase(250, 1000, 0.25, 'repeat'), 0.5, 'phase offset changed', scope)

h.assert_equal(
  transforms.apply('#808080', { type = 'brightness', value = 0.5 }),
  '#404040',
  'brightness transform changed',
  scope
)
h.assert_equal(
  transforms.apply('#202020', { type = 'brightness', value = 3 }),
  transforms.apply('#202020', { type = 'brightness', value = 2 }),
  'brightness transform was not clamped',
  scope
)
h.assert_equal(
  transforms.apply('#808080', { type = 'saturation', value = 0 }),
  '#808080',
  'zero saturation on gray changed',
  scope
)
h.assert_equal(
  transforms.apply('#804020', { type = 'saturation', value = 3 }),
  transforms.apply('#804020', { type = 'saturation', value = 2 }),
  'saturation transform was not clamped',
  scope
)
h.assert_equal(
  transforms.apply('#ff0000', { type = 'hue_shift', value = 120 }),
  '#00ff00',
  'hue shift transform changed',
  scope
)

h.assert_equal(
  effects.compute({
    version = 1,
    duration = 2000,
    loop = 'repeat',
    interpolation = 'linear',
    timeline = {
      { at = 0, color = '#000000' },
      { at = 1, color = '#ffffff' },
    },
  }, '#123456', 1000),
  '#808080',
  'linear custom effect sample changed',
  scope
)
h.assert_equal(
  effects.compute({
    version = 1,
    duration = 2000,
    loop = 'repeat',
    interpolation = 'step',
    timeline = {
      { at = 0, color = '#000000' },
      { at = 1, color = '#ffffff' },
    },
  }, '#123456', 1000),
  '#000000',
  'step custom effect sample changed',
  scope
)
h.assert_equal(
  effects.compute({
    version = 1,
    duration = 2000,
    loop = 'pingpong',
    interpolation = 'linear',
    timeline = {
      { at = 0, color = '#000000' },
      { at = 1, color = '#ffffff' },
    },
  }, '#123456', 3000),
  '#808080',
  'pingpong custom effect sample changed',
  scope
)
h.assert_equal(
  effects.compute({
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
          { at = 0, value = 0.5 },
          { at = 1, value = 0.5 },
        },
      },
    },
  }, '#808080', 1000),
  '#404040',
  'brightness custom effect transform changed',
  scope
)
h.assert_equal(
  effects.compute({
    version = 1,
    duration = 2000,
    loop = 'once',
    interpolation = 'linear',
    timeline = {
      { at = 0, color = 'base' },
      { at = 1, color = 'fg' },
    },
  }, '#123456', 0, {}),
  '#123456',
  'unused unresolved color ref blocked effect sampling',
  scope
)

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

print('hlcraft dynamic: OK')
