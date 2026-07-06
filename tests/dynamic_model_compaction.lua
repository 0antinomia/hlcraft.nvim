local h = require('tests.helpers')
local scope = 'hlcraft dynamic model compaction'

local model = require('hlcraft.dynamic.model')

local normalized_custom = assert(
  model.normalize_channel({
    version = 1,
    preset = 'manual',
    duration = 1750,
    loop = 'repeat',
    phase = 0.25,
    interpolation = 'smooth',
    timeline = {
      { at = 0, color = 'base' },
      { at = 1, color = '#ffffff' },
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
  }),
  'custom dynamic fixture did not normalize'
)

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

h.assert_true(model.compact_dynamic({
  fg = {
    version = 1,
    timeline = { { at = 0, color = 'base' } },
  },
  bg = {
    version = 1,
    timeline = {},
  },
}) == nil, 'compact dynamic silently dropped an invalid channel', scope)

print('hlcraft dynamic model compaction: OK')
