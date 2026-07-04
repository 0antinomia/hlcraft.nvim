local h = require('tests.helpers')
local scope = 'hlcraft ui search scene'

local search_scene = require('hlcraft.ui.scene.search')
local ui_state = require('hlcraft.ui.state')

local instance = {
  state = {
    buf = nil,
    color_query = '',
    detail_index = nil,
    field_editor = ui_state.field_editor(),
    geometry = ui_state.geometry(),
    list_cursor = 1,
    name_query = '',
    results = {
      { name = 'Alpha' },
      { name = 'Beta' },
    },
    scene = ui_state.search_scene(),
  },
  rerender = function() end,
}

instance.state.geometry.result_lines = {
  [8] = 2,
  [4] = 1,
}

local rows = search_scene.rows(instance)
h.assert_equal(rows[1].line, 4, 'search rows were not sorted by line', scope)
h.assert_equal(rows[2].index, 2, 'search rows lost result index', scope)
local missing_result_lines_ok = pcall(search_scene.rows, {
  state = {
    geometry = {},
  },
})
h.assert_true(not missing_result_lines_ok, 'search scene accepted missing result_lines geometry', scope)

h.assert_true(not search_scene.goto_first(instance), 'goto_first reported movement without a window', scope)
h.assert_true(not search_scene.goto_offset(instance, 1), 'goto_offset reported movement without a window', scope)
h.assert_true(not search_scene.open_detail(instance), 'open_detail reported success without a window', scope)

local ok, err = search_scene.handle(instance, 'open_detail')
h.assert_true(not ok, 'open_detail action succeeded without a window', scope)
h.assert_true(err == nil, 'open_detail action reported an unexpected error', scope)
local activate_ok, activate_err = search_scene.handle(instance, 'activate')
h.assert_true(not activate_ok, 'activate action succeeded without a window', scope)
h.assert_true(activate_err == nil, 'activate action reported an unexpected error', scope)

print('hlcraft ui search scene: OK')
