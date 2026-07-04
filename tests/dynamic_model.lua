local h = require('tests.helpers')
local scope = 'hlcraft dynamic model'

local constants = require('hlcraft.dynamic.constants')
local fields = require('hlcraft.core.fields')
local model = require('hlcraft.dynamic.model')
local presets = require('hlcraft.dynamic.presets')

h.assert_true(vim.deep_equal(model.channels, fields.color_keys), 'dynamic channels drifted from color fields', scope)
h.assert_true(
  vim.deep_equal(model.channel_set, fields.color_set),
  'dynamic channel set drifted from color fields',
  scope
)
h.assert_equal(model.version, constants.version, 'model version drifted from dynamic constants', scope)
h.assert_equal(
  model.default_duration,
  constants.default_duration,
  'model default duration drifted from dynamic constants',
  scope
)
h.assert_equal(
  model.default_interpolation,
  constants.default_interpolation,
  'model default interpolation drifted from dynamic constants',
  scope
)
h.assert_equal(model.default_loop, constants.default_loop, 'model default loop drifted from dynamic constants', scope)
h.assert_equal(
  model.default_phase,
  constants.default_phase,
  'model default phase drifted from dynamic constants',
  scope
)

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

local compacted_default = model.compact_channel({
  version = 1,
  duration = model.default_duration,
  loop = model.default_loop,
  phase = model.default_phase,
  interpolation = model.default_interpolation,
  timeline = {
    { at = 0, color = 'base' },
  },
  transforms = {},
})
h.assert_equal(compacted_default.version, 1, 'compact dynamic spec dropped version', scope)
h.assert_equal(compacted_default.timeline[1].color, 'base', 'compact dynamic spec dropped timeline', scope)
h.assert_true(compacted_default.duration == nil, 'compact dynamic spec kept default duration', scope)
h.assert_true(compacted_default.loop == nil, 'compact dynamic spec kept default loop', scope)
h.assert_true(compacted_default.phase == nil, 'compact dynamic spec kept default phase', scope)
h.assert_true(compacted_default.interpolation == nil, 'compact dynamic spec kept default interpolation', scope)
h.assert_true(compacted_default.transforms == nil, 'compact dynamic spec kept empty transforms', scope)
local normalized_from_compact = model.normalize_channel(compacted_default)
h.assert_equal(
  normalized_from_compact.duration,
  model.default_duration,
  'compact dynamic spec did not restore default duration',
  scope
)
h.assert_equal(
  normalized_from_compact.interpolation,
  model.default_interpolation,
  'compact dynamic spec did not restore default interpolation',
  scope
)

local compacted_custom = model.compact_channel(normalized_custom)
h.assert_equal(compacted_custom.duration, 1750, 'compact dynamic spec dropped custom duration', scope)
h.assert_true(compacted_custom.loop == nil, 'compact dynamic spec kept default loop', scope)
h.assert_equal(compacted_custom.phase, 0.25, 'compact dynamic spec dropped custom phase', scope)
h.assert_equal(compacted_custom.interpolation, 'smooth', 'compact dynamic spec dropped custom interpolation', scope)
h.assert_equal(compacted_custom.transforms[1].timeline[2].value, 1.25, 'compact dynamic spec dropped transforms', scope)
h.assert_true(
  compacted_custom.transforms[1].interpolation == nil,
  'compact dynamic spec kept default transform interpolation',
  scope
)

local compacted_once = model.compact_channel({
  version = 1,
  loop = 'once',
  timeline = {
    { at = 0, color = 'base' },
  },
})
h.assert_equal(compacted_once.loop, 'once', 'compact dynamic spec dropped non-default loop', scope)

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
h.assert_true(model.normalize_channel({
  version = 1,
  timeline = { { at = 0, color = 'base' } },
  transforms = {
    brightness = {
      type = 'brightness',
      timeline = {
        { at = 0, value = 1 },
      },
    },
  },
}) == nil, 'non-array transforms table was accepted', scope)
h.assert_true(
  model.normalize_channel({ timeline = { { at = 0, color = 'base' } } }) == nil,
  'missing version was accepted',
  scope
)

local normalized_entry = model.normalize_entry({
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
h.assert_equal(normalized_entry.dynamic.fg.preset, 'pulse', 'dynamic fg did not normalize', scope)
h.assert_equal(normalized_entry.dynamic.fg.duration, 1500, 'dynamic duration did not normalize', scope)
h.assert_true(type(normalized_entry.dynamic.fg) == 'table', 'dynamic fg did not stay nested data', scope)

for _, preset_name in ipairs(presets.names()) do
  local preset = presets.get(preset_name)
  h.assert_equal(preset.version, 1, ('preset %s version changed'):format(preset_name), scope)
  h.assert_equal(preset.preset, preset_name, ('preset %s label changed'):format(preset_name), scope)
  h.assert_true(model.normalize_channel(preset) ~= nil, ('preset %s did not normalize'):format(preset_name), scope)
end

local fallback_preset = presets.get('unknown')
h.assert_equal(fallback_preset.preset, 'pulse', 'unknown preset did not fall back to pulse', scope)

print('hlcraft dynamic model: OK')
