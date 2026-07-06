local h = require('tests.helpers')
local scope = 'hlcraft dynamic model normalization'

local model = require('hlcraft.dynamic.model')

local function channel_spec(extra)
  if extra == nil then
    extra = {}
  end
  return vim.tbl_extend('force', {
    version = 1,
    timeline = { { at = 0, color = 'base' } },
  }, extra)
end

local function brightness_transform(extra)
  if extra == nil then
    extra = {}
  end
  return vim.tbl_extend('force', {
    type = 'brightness',
    timeline = { { at = 0, value = 1 } },
  }, extra)
end

local normalized_custom = model.normalize_channel({
  version = 1,
  preset = ' manual ',
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
h.assert_equal(normalized_custom.preset, 'manual', 'custom preset label did not normalize', scope)
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

for _, case in ipairs({
  {
    message = 'unsupported version was accepted',
    spec = channel_spec({ version = 2 }),
  },
  {
    message = 'empty timeline was accepted',
    spec = channel_spec({ timeline = {} }),
  },
  {
    message = 'invalid color reference was accepted',
    spec = channel_spec({ timeline = { { at = 0, color = 'bad-color' } } }),
  },
  {
    message = 'invalid duration type was accepted',
    spec = channel_spec({ duration = '1000' }),
  },
  {
    message = 'invalid loop was accepted',
    spec = channel_spec({ loop = 'bad' }),
  },
  {
    message = 'invalid phase was accepted',
    spec = channel_spec({ phase = '0.5' }),
  },
  {
    message = 'invalid interpolation was accepted',
    spec = channel_spec({ interpolation = 'bad' }),
  },
  {
    message = 'invalid preset was accepted',
    spec = channel_spec({ preset = '' }),
  },
  {
    message = 'blank preset was accepted',
    spec = channel_spec({ preset = '   ' }),
  },
  {
    message = 'missing color stop at was accepted',
    spec = channel_spec({ timeline = { { color = 'base' } } }),
  },
  {
    message = 'invalid color stop at was accepted',
    spec = channel_spec({ timeline = { { at = 'bad', color = 'base' } } }),
  },
  {
    message = 'out-of-range color stop at was accepted',
    spec = channel_spec({ timeline = { { at = 1.01, color = 'base' } } }),
  },
  {
    message = 'missing transform stop at was accepted',
    spec = channel_spec({
      transforms = {
        brightness_transform({ timeline = { { value = 1 } } }),
      },
    }),
  },
  {
    message = 'invalid transform stop at was accepted',
    spec = channel_spec({
      transforms = {
        brightness_transform({ timeline = { { at = 'bad', value = 1 } } }),
      },
    }),
  },
  {
    message = 'out-of-range transform stop at was accepted',
    spec = channel_spec({
      transforms = {
        brightness_transform({ timeline = { { at = -0.01, value = 1 } } }),
      },
    }),
  },
  {
    message = 'non-sequence color timeline was accepted',
    spec = channel_spec({
      timeline = {
        { at = 0, color = 'base' },
        named = { at = 1, color = '#ffffff' },
      },
    }),
  },
  {
    message = 'non-sequence transform timeline was accepted',
    spec = channel_spec({
      transforms = {
        brightness_transform({
          timeline = {
            { at = 0, value = 1 },
            named = { at = 1, value = 0.5 },
          },
        }),
      },
    }),
  },
  {
    message = 'unknown dynamic channel key was accepted',
    spec = channel_spec({ unknown = true }),
  },
  {
    message = 'unknown color stop key was accepted',
    spec = channel_spec({
      timeline = { { at = 0, color = 'base', unknown = true } },
    }),
  },
  {
    message = 'unknown transform key was accepted',
    spec = channel_spec({
      transforms = {
        brightness_transform({ unknown = true }),
      },
    }),
  },
  {
    message = 'invalid transform interpolation was accepted',
    spec = channel_spec({
      transforms = {
        brightness_transform({ interpolation = 'bad' }),
      },
    }),
  },
  {
    message = 'unknown transform stop key was accepted',
    spec = channel_spec({
      transforms = {
        brightness_transform({
          timeline = { { at = 0, value = 1, unknown = true } },
        }),
      },
    }),
  },
  {
    message = 'non-array transforms table was accepted',
    spec = channel_spec({
      transforms = {
        brightness = brightness_transform(),
      },
    }),
  },
  {
    message = 'missing version was accepted',
    spec = { timeline = { { at = 0, color = 'base' } } },
  },
}) do
  h.assert_true(model.normalize_channel(case.spec) == nil, case.message, scope)
end

h.assert_true(model.normalize_dynamic({
  fg = {
    version = 1,
    timeline = { { at = 0, color = 'base' } },
  },
  unknown = {
    version = 1,
    timeline = { { at = 0, color = 'base' } },
  },
}) == nil, 'unknown dynamic root key was accepted', scope)

h.assert_true(model.normalize_dynamic({
  fg = {
    version = 1,
    timeline = { { at = 0, color = 'base' } },
  },
  bg = {
    version = 1,
    timeline = {},
  },
}) == nil, 'invalid dynamic channel was silently dropped', scope)

print('hlcraft dynamic model normalization: OK')
