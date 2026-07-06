local h = require('tests.helpers')
local scope = 'hlcraft dynamic model contract'

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
  'model default duration drifted from constants',
  scope
)
h.assert_equal(
  model.default_interpolation,
  constants.default_interpolation,
  'model default interpolation drifted from constants',
  scope
)
h.assert_equal(model.default_loop, constants.default_loop, 'model default loop drifted from constants', scope)
h.assert_equal(model.default_phase, constants.default_phase, 'model default phase drifted from constants', scope)

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

print('hlcraft dynamic model contract: OK')
