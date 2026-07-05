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

local function assert_fails(fn, message)
  h.assert_true(not pcall(fn), message, scope)
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
assert_fails(function()
  navigation.allowed_rows(nil)
end, 'navigation accepted missing instance')
assert_fails(function()
  navigation.allowed_rows({ state = false })
end, 'navigation accepted invalid state')
assert_fails(function()
  navigation.nearest_allowed_row(search_instance, 0)
end, 'navigation accepted zero row')
assert_fails(function()
  navigation.nearest_allowed_row(search_instance, math.huge)
end, 'navigation accepted infinite row')
assert_fails(function()
  navigation.adjacent_allowed_row(search_instance, 4, 1.5)
end, 'navigation accepted fractional step')
assert_fails(function()
  navigation.adjacent_allowed_row(search_instance, 4, 0 / 0)
end, 'navigation accepted NaN step')

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
local invalid_geometry_ok = pcall(navigation.allowed_rows, {
  state = {
    geometry = {},
  },
})
h.assert_true(not invalid_geometry_ok, 'navigation accepted missing geometry inputs', scope)
local sparse_input_rows_ok = pcall(navigation.allowed_rows, {
  state = {
    geometry = vim.tbl_extend('force', ui_state.geometry(), {
      inputs = {
        [2] = { line = 4 },
      },
    }),
  },
})
h.assert_true(not sparse_input_rows_ok, 'navigation accepted sparse input geometry', scope)

local invalid_input_row_instance = {
  state = {
    geometry = ui_state.geometry(),
  },
}
invalid_input_row_instance.state.geometry.inputs = {
  { line = '2' },
}
assert_fails(function()
  navigation.allowed_rows(invalid_input_row_instance)
end, 'navigation accepted invalid input row')

local invalid_result_row_instance = {
  state = {
    geometry = ui_state.geometry(),
  },
}
invalid_result_row_instance.state.geometry.result_lines = {
  [0] = 1,
}
assert_fails(function()
  navigation.allowed_rows(invalid_result_row_instance)
end, 'navigation accepted invalid result row')

local invalid_detail_row_instance = {
  state = {
    detail_index = 1,
    geometry = ui_state.geometry(),
  },
}
invalid_detail_row_instance.state.geometry.detail_menu = {
  fg = { line = 0 },
}
assert_fails(function()
  navigation.allowed_rows(invalid_detail_row_instance)
end, 'navigation accepted invalid detail row')

local invalid_editor_row_instance = {
  state = {
    detail_index = 1,
    geometry = ui_state.geometry(),
  },
}
invalid_editor_row_instance.state.geometry.editor_rows = {
  dynamic_loop = { line = 1.5 },
}
assert_fails(function()
  navigation.allowed_rows(invalid_editor_row_instance)
end, 'navigation accepted invalid editor row')

local invalid_window_instance = {
  state = {
    buf = nil,
    clamping_cursor = false,
    geometry = ui_state.geometry(),
  },
}
invalid_window_instance.state.geometry.result_lines = {
  [3] = 1,
}

h.assert_true(not navigation.clamp_cursor(invalid_window_instance), 'invalid window clamp reported movement', scope)
assert_fails(function()
  navigation.clamp_cursor(nil)
end, 'navigation clamp accepted missing instance')
assert_fails(function()
  navigation.jump_to_row(nil, 3, false)
end, 'navigation jump accepted missing instance')
assert_fails(function()
  navigation.jump_to_row(invalid_window_instance, 0, false)
end, 'navigation jump accepted invalid target row')
assert_fails(function()
  navigation.jump_to_row(invalid_window_instance, 3, nil)
end, 'navigation jump accepted missing insert flag')
h.assert_true(
  not navigation.jump_to_row(invalid_window_instance, 3, false),
  'invalid window jump reported movement',
  scope
)
assert_fails(function()
  navigation.move_interactive(nil, 1)
end, 'navigation move accepted missing instance')
assert_fails(function()
  navigation.move_interactive(invalid_window_instance, math.huge)
end, 'navigation move accepted infinite step')
h.assert_true(
  not navigation.move_interactive(invalid_window_instance, 1),
  'invalid window move reported movement',
  scope
)

print('hlcraft ui navigation: OK')
