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
h.assert_true(timeline.phase(0 / 0, 1000, 0, 'repeat') == nil, 'NaN phase time was accepted', scope)
h.assert_true(timeline.phase(250, 0, 0, 'repeat') == nil, 'zero duration was accepted', scope)
h.assert_true(timeline.phase(250, 1000, 0, 'bad') == nil, 'unknown loop was accepted', scope)
h.assert_true(timeline.sample_numeric(numeric_stops, 0 / 0, 'linear') == nil, 'NaN sample phase was accepted', scope)
h.assert_true(timeline.sample_numeric(numeric_stops, 0.5, 'bad') == nil, 'unknown interpolation was accepted', scope)
h.assert_true(timeline.sample_numeric({ false }, 0.5, 'linear') == nil, 'non-table stop was accepted', scope)
h.assert_true(timeline.sample_numeric({
  [2] = { at = 1, value = 1 },
}, 0.5, 'linear') == nil, 'sparse numeric stops were accepted', scope)
h.assert_true(
  timeline.sample_numeric({ { at = 0, value = 0 }, { value = 1 } }, 0.5, 'linear') == nil,
  'stop without position was accepted',
  scope
)
h.assert_true(
  timeline.sample_numeric({ { at = 0 }, { at = 1, value = 1 } }, 0.5, 'linear') == nil,
  'numeric stop without value was accepted',
  scope
)

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
  nil,
  'NaN brightness transform was accepted',
  scope
)
h.assert_equal(
  transforms.apply('#202020', { type = 'unknown', value = 1 }),
  nil,
  'unknown transform type was accepted',
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
h.assert_equal(
  compute({
    version = 1,
    timeline = {
      { at = 0, color = 'base' },
    },
  }, tonumber('123456', 16), 0),
  '#123456',
  'numeric base color stopped resolving',
  scope
)
h.assert_true(compute({
  version = 1,
  timeline = {
    { at = 0, color = 'base' },
  },
}, 0x1000000, 0) == nil, 'effect accepted invalid numeric base color', scope)
h.assert_true(compute(
  {
    version = 1,
    timeline = {
      { at = 0, color = 'fg' },
    },
  },
  '#123456',
  0,
  {
    fg = 0x1000000,
  }
) == nil, 'effect accepted invalid numeric context color', scope)
h.assert_true(compute({
  version = 1,
  duration = 2000,
  loop = 'repeat',
  interpolation = 'linear',
  timeline = {
    { at = 0, color = '#000000' },
    { at = 1, color = '#ffffff' },
  },
}, '#123456', 0 / 0) == nil, 'effect accepted invalid sampling time', scope)

print('hlcraft dynamic effects: OK')
