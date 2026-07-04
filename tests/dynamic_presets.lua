local h = require('tests.helpers')
local scope = 'hlcraft dynamic presets'

local model = require('hlcraft.dynamic.model')
local presets = require('hlcraft.dynamic.presets')

local default_spec = model.default_spec('pulse')
h.assert_equal(default_spec.version, 1, 'default dynamic version changed', scope)
h.assert_equal(default_spec.preset, 'pulse', 'default dynamic preset changed', scope)
h.assert_equal(default_spec.duration, 2000, 'default dynamic duration changed', scope)
h.assert_equal(default_spec.loop, 'pingpong', 'default dynamic loop changed', scope)
h.assert_equal(default_spec.timeline[1].color, 'base', 'default dynamic first color changed', scope)
h.assert_equal(default_spec.timeline[2].color, '#ff6699', 'default dynamic second color changed', scope)

local expected_names = { 'pulse', 'breath', 'hue', 'gradient', 'blink', 'duotone' }
h.assert_true(vim.deep_equal(presets.names(), expected_names), 'preset order changed', scope)

for _, preset_name in ipairs(presets.names()) do
  local preset = presets.get(preset_name)
  h.assert_equal(preset.version, 1, ('preset %s version changed'):format(preset_name), scope)
  h.assert_equal(preset.preset, preset_name, ('preset %s label changed'):format(preset_name), scope)
  h.assert_true(model.normalize_channel(preset) ~= nil, ('preset %s did not normalize'):format(preset_name), scope)
end

local fallback_preset = presets.get('unknown')
h.assert_equal(fallback_preset.preset, 'pulse', 'unknown preset did not fall back to pulse', scope)

print('hlcraft dynamic presets: OK')
