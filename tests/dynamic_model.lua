local h = require('tests.helpers')
local scope = 'hlcraft dynamic model'

local constants = require('hlcraft.dynamic.constants')
local fields = require('hlcraft.core.fields')
local model = require('hlcraft.dynamic.model')

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
for _, loop in ipairs(constants.loops) do
  h.assert_equal(model.normalize_loop(loop), loop, ('loop %s was not accepted'):format(loop), scope)
end
h.assert_true(model.normalize_loop('bad') == nil, 'invalid loop helper fell back to default', scope)
for _, interpolation in ipairs(constants.interpolations) do
  h.assert_equal(
    model.normalize_interpolation(interpolation),
    interpolation,
    ('interpolation %s was not accepted'):format(interpolation),
    scope
  )
end
h.assert_true(model.normalize_interpolation('bad') == nil, 'invalid interpolation helper fell back to default', scope)
h.assert_equal(
  model.normalize_duration(constants.min_duration - 1),
  constants.min_duration,
  'duration helper did not clamp low values',
  scope
)
h.assert_equal(
  model.normalize_duration(constants.max_duration + 1),
  constants.max_duration,
  'duration helper did not clamp high values',
  scope
)
local invalid_duration_ok = pcall(model.normalize_duration, '1000')
h.assert_true(not invalid_duration_ok, 'duration helper accepted a string value', scope)
local non_finite_duration_ok = pcall(model.normalize_duration, 0 / 0)
h.assert_true(not non_finite_duration_ok, 'duration helper accepted a non-finite value', scope)
for _, transform_type in ipairs(constants.transform_types) do
  h.assert_true(model.normalize_transform({
    type = transform_type,
    timeline = {
      { at = 0, value = 1 },
    },
  }) ~= nil, ('transform type %s was not accepted'):format(transform_type), scope)
end

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
local nil_entry_ok = pcall(model.normalize_entry, nil)
h.assert_true(not nil_entry_ok, 'dynamic entry normalization accepted nil entry', scope)

print('hlcraft dynamic model: OK')
