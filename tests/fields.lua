local h = require('tests.helpers')
local scope = 'hlcraft fields'

local core_fields = require('hlcraft.core.fields')
local ui_fields = require('hlcraft.ui.fields')

local function list_set(list)
  local result = {}
  for _, key in ipairs(list) do
    result[key] = true
  end
  return result
end

local detail_set = list_set(ui_fields.detail_order)

h.assert_equal(core_fields.color_keys[1], 'fg', 'color field order changed', scope)
h.assert_true(core_fields.color_set.fg, 'color field set lacks fg', scope)
h.assert_true(core_fields.style_set.underdashed, 'style field set lacks underdashed', scope)
h.assert_true(core_fields.override_set.blend, 'override field set lacks blend', scope)

for _, key in ipairs(core_fields.override_keys) do
  h.assert_true(detail_set[key], ('ui detail fields do not expose %s'):format(key), scope)
  h.assert_true(ui_fields.detail_labels[key] ~= nil, ('ui detail field %s lacks a label'):format(key), scope)
  h.assert_true(ui_fields.detail_kinds[key] ~= nil, ('ui detail field %s lacks a kind'):format(key), scope)
end

h.assert_equal(ui_fields.detail_order[1], 'group', 'group field must stay first', scope)
h.assert_equal(ui_fields.detail_kinds.fg, 'color', 'fg kind changed', scope)
h.assert_equal(ui_fields.detail_kinds.underdashed, 'boolean', 'underdashed kind changed', scope)
h.assert_equal(ui_fields.detail_kinds.blend, 'blend', 'blend kind changed', scope)

print('hlcraft fields: OK')
