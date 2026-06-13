local h = require('tests.helpers')
local scope = 'hlcraft persistence schema'

local schema = require('hlcraft.persistence.schema')

local inflated = schema.inflate_entry({
  fg = '#101010',
  dyn_fg_mode = 'rgb',
  dyn_fg_speed = 1500,
  dyn_fg_palette = '["#000000","#ffffff"]',
  dyn_bg_mode = 'breath',
  dyn_bg_params = '{"min":0.2,"max":0.8}',
})

h.assert_equal(inflated.dynamic.fg.mode, 'rgb', 'rgb mode did not inflate', scope)
h.assert_equal(inflated.dynamic.fg.palette[2], '#ffffff', 'rgb palette did not inflate', scope)
h.assert_equal(inflated.dynamic.bg.params.max, 0.8, 'breath params did not inflate', scope)
h.assert_true(inflated.dyn_fg_mode == nil, 'flat dynamic key leaked after inflate', scope)

local flattened = schema.flatten_entry(inflated)
h.assert_equal(flattened.dyn_fg_mode, 'rgb', 'rgb mode did not flatten', scope)
h.assert_true(type(flattened.dyn_fg_palette) == 'string', 'rgb palette did not flatten', scope)
h.assert_equal(flattened.dyn_bg_mode, 'breath', 'breath mode did not flatten', scope)

print('hlcraft persistence schema: OK')
