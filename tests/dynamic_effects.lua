local h = require('tests.helpers')
local scope = 'hlcraft dynamic effects'

local effects = require('hlcraft.dynamic.effects')
local model = require('hlcraft.dynamic.model')
local timeline = require('hlcraft.dynamic.timeline')
local transforms = require('hlcraft.dynamic.transforms')

local function normalize(spec)
  return assert(model.normalize_channel(spec), 'dynamic spec fixture did not normalize')
end

local function compute(spec, base_hex, now_ms, context)
  return effects.compute(normalize(spec), base_hex, now_ms, context)
end

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
h.assert_equal(timeline.phase(0 / 0, 1000, 0, 'repeat'), 0, 'NaN phase time did not fall back', scope)
h.assert_equal(timeline.sample_numeric(numeric_stops, 0 / 0, 'linear'), 0, 'NaN sample phase did not fall back', scope)

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
  transforms.apply('#202020', { type = 'brightness', value = 0 / 0 }),
  '#202020',
  'NaN brightness should not change color',
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
  compute({
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
  compute({
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
  compute({
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
  compute({
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
  compute({
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

print('hlcraft dynamic effects: OK')
