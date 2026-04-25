local h = require('tests.helpers')
local scope = 'hlcraft config'

local config = require('hlcraft.config')

local default_group_config_ok = config.validate({ default_group = 'default' })
h.assert_true(not default_group_config_ok, 'default_group config option is still accepted', scope)

local debug_config_ok = config.validate({ debug = { level = 'trace' } })
h.assert_true(not debug_config_ok, 'debug config option is still accepted', scope)

local empty_persist_dir_ok = config.validate({ persist_dir = '' })
h.assert_true(not empty_persist_dir_ok, 'empty persist_dir config option is still accepted', scope)

local valid_reapply_ok, valid_reapply_err = config.validate({
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
      { event = 'SessionLoadPost', once = false, pattern = '*' },
    },
  },
})
h.assert_true(valid_reapply_ok, valid_reapply_err or 'structured reapply_events config was rejected', scope)

local invalid_reapply_ok = config.validate({
  reapply_events = {
    enabled = true,
    events = {
      { pattern = '*' },
    },
  },
})
h.assert_true(not invalid_reapply_ok, 'invalid structured reapply event was accepted', scope)

print('hlcraft config: OK')
