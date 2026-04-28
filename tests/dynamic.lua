local h = require('tests.helpers')
local scope = 'hlcraft dynamic'

local model = require('hlcraft.dynamic.model')
local effects = require('hlcraft.dynamic.effects')

local default_spec = model.default_spec()
h.assert_equal(default_spec.mode, 'rgb', 'default mode is wrong', scope)
h.assert_equal(default_spec.speed, 2000, 'default speed is wrong', scope)

local normalized = model.normalize_channel({ mode = 'breath', speed = 3000 })
h.assert_equal(normalized.mode, 'breath', 'breath mode did not normalize', scope)
h.assert_equal(normalized.speed, 3000, 'speed did not normalize', scope)

local fallback_speed = model.normalize_channel({ mode = 'rgb', speed = 'fast' })
h.assert_equal(fallback_speed.speed, 2000, 'invalid speed did not use default', scope)

local unsupported = model.normalize_channel({ mode = 'sparkle', speed = 3000 })
h.assert_true(unsupported == nil, 'unsupported mode was accepted', scope)

local entry = model.inflate_entry({
  fg = '#101010',
  dyn_fg_mode = 'rgb',
  dyn_fg_speed = 1500,
  dyn_bg_mode = 'breath',
  dyn_bg_speed = 'bad',
})
h.assert_equal(entry.dynamic.fg.mode, 'rgb', 'dyn_fg_mode did not inflate', scope)
h.assert_equal(entry.dynamic.fg.speed, 1500, 'dyn_fg_speed did not inflate', scope)
h.assert_equal(entry.dynamic.bg.mode, 'breath', 'dyn_bg_mode did not inflate', scope)
h.assert_equal(entry.dynamic.bg.speed, 2000, 'invalid dyn_bg_speed did not default', scope)
h.assert_true(entry.dyn_fg_mode == nil, 'flat dyn key was not removed during inflate', scope)
h.assert_true(entry.dyn_fg_speed == nil, 'flat dyn speed key was not removed during inflate', scope)
h.assert_true(entry.dyn_bg_mode == nil, 'flat dyn bg mode key was not removed during inflate', scope)
h.assert_true(entry.dyn_bg_speed == nil, 'flat dyn bg speed key was not removed during inflate', scope)

local flat = model.flatten_entry({
  fg = '#101010',
  dynamic = {
    fg = { mode = 'rgb', speed = 1500 },
    sp = { mode = 'breath', speed = 2500 },
  },
})
h.assert_equal(flat.dyn_fg_mode, 'rgb', 'dynamic fg mode did not flatten', scope)
h.assert_equal(flat.dyn_fg_speed, 1500, 'dynamic fg speed did not flatten', scope)
h.assert_equal(flat.dyn_sp_mode, 'breath', 'dynamic sp mode did not flatten', scope)
h.assert_equal(flat.dyn_sp_speed, 2500, 'dynamic sp speed did not flatten', scope)
h.assert_true(flat.dynamic == nil, 'runtime dynamic table leaked into flat entry', scope)

h.assert_equal(effects.rgb(0, 3000), '#ff0000', 'rgb start color is wrong', scope)
h.assert_equal(effects.rgb(1000, 3000), '#00ff00', 'rgb one-third color is wrong', scope)
h.assert_equal(effects.rgb(2000, 3000), '#0000ff', 'rgb two-third color is wrong', scope)

local breath_low = effects.breath('#808080', 0, 2000)
local breath_high = effects.breath('#808080', 1000, 2000)
h.assert_true(breath_low ~= breath_high, 'breath color did not change over phase', scope)
h.assert_true(effects.breath('NONE', 1000, 2000) == nil, 'breath accepted NONE base color', scope)

print('hlcraft dynamic: OK')
