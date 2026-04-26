local h = require('tests.helpers')
local scope = 'hlcraft config'

local config = require('hlcraft.config')

local default_group_config_ok = config.validate({ default_group = 'default' })
h.assert_true(not default_group_config_ok, 'default_group config option is still accepted', scope)

local debug_config_ok = config.validate({ debug = { level = 'trace' } })
h.assert_true(not debug_config_ok, 'debug config option is still accepted', scope)

local empty_persist_dir_ok = config.validate({ persist_dir = '' })
h.assert_true(not empty_persist_dir_ok, 'empty persist_dir config option is still accepted', scope)

local empty_config_ok, empty_config_err = config.validate({})
h.assert_true(empty_config_ok, empty_config_err or 'empty config table was rejected', scope)

local from_none_bool_ok, from_none_bool_err = config.validate({ from_none = true })
h.assert_true(from_none_bool_ok, from_none_bool_err or 'boolean from_none=true was rejected', scope)

local from_none_empty_ok, from_none_empty_err = config.validate({ from_none = {} })
h.assert_true(from_none_empty_ok, from_none_empty_err or 'empty from_none table was rejected', scope)

local from_none_scope_only_ok, from_none_scope_only_err = config.validate({
  from_none = {
    scope = 'core',
  },
})
h.assert_true(from_none_scope_only_ok, from_none_scope_only_err or 'from_none scope-only config was rejected', scope)

local from_none_enabled_only_ok, from_none_enabled_only_err = config.validate({
  from_none = {
    enabled = true,
  },
})
h.assert_true(
  from_none_enabled_only_ok,
  from_none_enabled_only_err or 'from_none enabled-only config was rejected',
  scope
)

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

local disabled_reapply_bool_ok, disabled_reapply_bool_err = config.validate({ reapply_events = false })
h.assert_true(disabled_reapply_bool_ok, disabled_reapply_bool_err or 'boolean reapply_events=false was rejected', scope)

local enabled_reapply_bool_ok, enabled_reapply_bool_err = config.validate({ reapply_events = true })
h.assert_true(enabled_reapply_bool_ok, enabled_reapply_bool_err or 'boolean reapply_events=true was rejected', scope)

local empty_reapply_table_ok, empty_reapply_table_err = config.validate({ reapply_events = {} })
h.assert_true(empty_reapply_table_ok, empty_reapply_table_err or 'empty reapply_events table was rejected', scope)

local enabled_reapply_table_ok, enabled_reapply_table_err = config.validate({
  reapply_events = {
    enabled = true,
  },
})
h.assert_true(
  enabled_reapply_table_ok,
  enabled_reapply_table_err or 'enabled reapply_events without events was rejected',
  scope
)

local disabled_reapply_table_ok, disabled_reapply_table_err = config.validate({
  reapply_events = {
    enabled = false,
  },
})
h.assert_true(
  disabled_reapply_table_ok,
  disabled_reapply_table_err or 'disabled reapply_events without events was rejected',
  scope
)

local events_only_reapply_ok, events_only_reapply_err = config.validate({
  reapply_events = {
    events = {
      'User',
    },
  },
})
h.assert_true(
  events_only_reapply_ok,
  events_only_reapply_err or 'events-only reapply_events config was rejected',
  scope
)

local invalid_reapply_ok = config.validate({
  reapply_events = {
    enabled = true,
    events = {
      { pattern = '*' },
    },
  },
})
h.assert_true(not invalid_reapply_ok, 'invalid structured reapply event was accepted', scope)

local default_config = config.setup({})
h.assert_equal(default_config.from_none.enabled, false, 'empty config did not keep default from_none.enabled', scope)
h.assert_equal(
  default_config.reapply_events.enabled,
  true,
  'empty config did not keep default reapply_events.enabled',
  scope
)

local from_none_empty = config.setup({ from_none = {} }).from_none
h.assert_equal(from_none_empty.enabled, false, 'empty from_none table did not default enabled to false', scope)
h.assert_equal(from_none_empty.scope, 'extended', 'empty from_none table did not default scope', scope)

local from_none_scope_only = config.setup({ from_none = { scope = 'core' } }).from_none
h.assert_equal(
  from_none_scope_only.enabled,
  false,
  'from_none scope-only config did not default enabled to false',
  scope
)
h.assert_equal(from_none_scope_only.scope, 'core', 'from_none scope-only config did not preserve scope', scope)

local from_none_enabled_only = config.setup({ from_none = { enabled = true } }).from_none
h.assert_equal(from_none_enabled_only.enabled, true, 'from_none enabled-only config did not preserve enabled', scope)
h.assert_equal(
  from_none_enabled_only.scope,
  'extended',
  'from_none enabled-only config did not use default scope',
  scope
)

local disabled_reapply = config.setup({ reapply_events = false }).reapply_events
h.assert_equal(disabled_reapply.enabled, false, 'boolean reapply_events=false did not disable reapply events', scope)

local enabled_reapply = config.setup({ reapply_events = true }).reapply_events
h.assert_equal(enabled_reapply.enabled, true, 'boolean reapply_events=true did not enable reapply events', scope)
h.assert_equal(
  enabled_reapply.events[1],
  'ColorScheme',
  'boolean reapply_events=true did not keep default events',
  scope
)

local empty_reapply_table = config.setup({ reapply_events = {} }).reapply_events
h.assert_equal(empty_reapply_table.enabled, true, 'empty reapply_events table did not default enabled to true', scope)
h.assert_equal(
  empty_reapply_table.events[1],
  'ColorScheme',
  'empty reapply_events table did not keep default events',
  scope
)

local enabled_reapply_without_events = config.setup({ reapply_events = { enabled = true } }).reapply_events
h.assert_equal(
  enabled_reapply_without_events.enabled,
  true,
  'enabled-only reapply_events did not preserve enabled',
  scope
)
h.assert_equal(
  enabled_reapply_without_events.events[1],
  'ColorScheme',
  'enabled-only reapply_events did not keep default events',
  scope
)

local disabled_reapply_without_events = config.setup({ reapply_events = { enabled = false } }).reapply_events
h.assert_equal(
  disabled_reapply_without_events.enabled,
  false,
  'table reapply_events.enabled=false did not disable reapply events',
  scope
)

local events_only_reapply = config.setup({
  reapply_events = {
    events = {
      'User',
    },
  },
}).reapply_events
h.assert_equal(events_only_reapply.enabled, true, 'events-only reapply_events did not default to enabled', scope)
h.assert_equal(events_only_reapply.events[1], 'User', 'events-only reapply_events did not preserve events', scope)

print('hlcraft config: OK')
