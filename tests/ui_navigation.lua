local h = require('tests.helpers')
local scope = 'hlcraft ui navigation'

local navigation = require('hlcraft.ui.navigation')
local ui_state = require('hlcraft.ui.state')

local function assert_list(actual, expected, message)
  h.assert_true(
    vim.deep_equal(actual, expected),
    ('%s (expected %s, got %s)'):format(message, vim.inspect(expected), vim.inspect(actual)),
    scope
  )
end

local search_instance = {
  state = {
    geometry = ui_state.geometry(),
  },
}
search_instance.state.geometry.inputs = {
  { line = 4 },
  { line = 2 },
}
search_instance.state.geometry.result_lines = {
  [8] = 1,
  [6] = 2,
}

assert_list(navigation.allowed_rows(search_instance), { 2, 4, 6, 8 }, 'search allowed rows changed')
h.assert_equal(navigation.nearest_allowed_row(search_instance, 5), 4, 'nearest row did not prefer lower tie', scope)
h.assert_equal(navigation.adjacent_allowed_row(search_instance, 4, 1), 6, 'next allowed row changed', scope)
h.assert_equal(navigation.adjacent_allowed_row(search_instance, 4, -1), 2, 'previous allowed row changed', scope)
h.assert_equal(navigation.adjacent_allowed_row(search_instance, 8, 1), 8, 'next allowed row did not clamp', scope)
h.assert_equal(
  navigation.adjacent_allowed_row(search_instance, 7, 1),
  6,
  'missing current row did not fall back to nearest',
  scope
)

local detail_instance = {
  state = {
    detail_index = 1,
    geometry = ui_state.geometry(),
  },
}
detail_instance.state.geometry.inputs = {
  { line = 2 },
}
detail_instance.state.geometry.result_lines = {
  [6] = 1,
}
detail_instance.state.geometry.detail_menu = {
  fg = { line = 3 },
}
detail_instance.state.geometry.editor_rows = {
  dynamic_loop = { line = 9 },
  dynamic_phase = { line = 7 },
}

assert_list(navigation.allowed_rows(detail_instance), { 3, 7, 9 }, 'detail allowed rows changed')

print('hlcraft ui navigation: OK')
