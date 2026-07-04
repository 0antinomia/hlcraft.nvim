local h = require('tests.helpers')
local scope = 'hlcraft ui field values'

local field_values = require('hlcraft.ui.field_values')

local result = {
  fg = '#101010',
  resolved_fg = '#202020',
  bg = '#303030',
  resolved_bg = 'NONE',
  sp = '#404040',
  blend = 12,
}

h.assert_equal(field_values.fallback_value(result, 'fg'), '#202020', 'fg did not prefer resolved value', scope)
h.assert_equal(field_values.fallback_value(result, 'bg'), '#303030', 'bg did not fall back when resolved NONE', scope)
h.assert_equal(field_values.fallback_value(result, 'sp'), '#404040', 'sp fallback changed', scope)
h.assert_equal(field_values.fallback_value(result, 'blend'), 12, 'generic fallback changed', scope)
local nil_result_ok = pcall(field_values.fallback_value, nil, 'fg')
h.assert_true(not nil_result_ok, 'field fallback accepted nil result', scope)
local non_string_key_ok = pcall(field_values.fallback_value, result, 1)
h.assert_true(not non_string_key_ok, 'field fallback accepted non-string key', scope)
local unknown_key_ok = pcall(field_values.fallback_value, result, 'unknown')
h.assert_true(not unknown_key_ok, 'field fallback accepted unknown key', scope)

h.assert_equal(field_values.display_text(nil), 'unset', 'nil display text changed', scope)
h.assert_equal(field_values.display_text(true), 'true', 'true display text changed', scope)
h.assert_equal(field_values.display_text(false), 'false', 'false display text changed', scope)
h.assert_equal(field_values.display_text('#101010'), '#101010', 'string display text changed', scope)
h.assert_equal(field_values.display_text(12), '12', 'number display text changed', scope)
local non_finite_display_ok = pcall(field_values.display_text, math.huge)
h.assert_true(not non_finite_display_ok, 'display text accepted non-finite number', scope)
local table_display_ok = pcall(field_values.display_text, {})
h.assert_true(not table_display_ok, 'display text accepted table value', scope)

print('hlcraft ui field values: OK')
