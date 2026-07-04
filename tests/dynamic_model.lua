local h = require('tests.helpers')
local scope = 'hlcraft dynamic model'

local model = require('hlcraft.dynamic.model')
local presets = require('hlcraft.dynamic.presets')

local default_spec = model.default_spec('pulse')
h.assert_equal(default_spec.version, 1, 'default dynamic version changed', scope)
h.assert_equal(default_spec.preset, 'pulse', 'default dynamic preset changed', scope)
h.assert_equal(default_spec.duration, 2000, 'default dynamic duration changed', scope)
h.assert_equal(default_spec.loop, 'pingpong', 'default dynamic loop changed', scope)
h.assert_equal(default_spec.timeline[1].color, 'base', 'default dynamic first color changed', scope)
h.assert_equal(default_spec.timeline[2].color, '#ff6699', 'default dynamic second color changed', scope)

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
h.assert_true(
  model.normalize_channel({ timeline = { { at = 0, color = 'base' } } }) == nil,
  'missing version was accepted',
  scope
)

local inflated = model.inflate_entry({
  fg = '#101010',
  dynamic = {
    fg = {
      version = 1,
      preset = 'pulse',
      duration = 1500,
      loop = 'pingpong',
      timeline = {
        { at = 0, color = 'base' },
        { at = 1, color = '#ffffff' },
      },
    },
  },
})
h.assert_equal(inflated.dynamic.fg.preset, 'pulse', 'dynamic fg did not inflate', scope)
h.assert_equal(inflated.dynamic.fg.duration, 1500, 'dynamic duration did not inflate', scope)

local flattened = model.flatten_entry(inflated)
h.assert_true(type(flattened.dynamic.fg) == 'table', 'dynamic fg did not flatten as nested data', scope)
h.assert_equal(flattened.dynamic.fg.preset, 'pulse', 'flattened preset changed', scope)
h.assert_equal(flattened.dynamic.fg.duration, 1500, 'flattened duration changed', scope)

for _, preset_name in ipairs({ 'pulse', 'breath', 'hue', 'gradient', 'blink', 'duotone' }) do
  local preset = presets.get(preset_name)
  h.assert_equal(preset.version, 1, ('preset %s version changed'):format(preset_name), scope)
  h.assert_equal(preset.preset, preset_name, ('preset %s label changed'):format(preset_name), scope)
  h.assert_true(model.normalize_channel(preset) ~= nil, ('preset %s did not normalize'):format(preset_name), scope)
end

local fallback_preset = presets.get('unknown')
h.assert_equal(fallback_preset.preset, 'pulse', 'unknown preset did not fall back to pulse', scope)

print('hlcraft dynamic model: OK')
