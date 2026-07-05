local h = require('tests.helpers')
local scope = 'hlcraft ui search scene'

local search_scene = require('hlcraft.ui.scene.search')
local ui_state = require('hlcraft.ui.state')

local function assert_fails(fn, message)
  h.assert_true(not pcall(fn), message, scope)
end

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
assert_fails(function()
  search_scene.enter(nil)
end, 'search scene accepted missing instance')
assert_fails(function()
  search_scene.enter({
    state = {},
  })
end, 'search scene accepted missing scene state')
assert_fails(function()
  search_scene.empty_message({
    state = {
      name_query = false,
      color_query = '',
    },
  })
end, 'search scene accepted invalid query state')
assert_fails(function()
  search_scene.update_results({
    state = {
      name_query = '',
      color_query = '',
    },
  })
end, 'search scene accepted missing list cursor state')
assert_fails(function()
  search_scene.rows({
    state = {
      geometry = {
        result_lines = {
          [0] = 1,
        },
      },
    },
  })
end, 'search scene accepted invalid result line')
assert_fails(function()
  search_scene.rows({
    state = {
      geometry = {
        result_lines = {
          [1] = math.huge,
        },
      },
    },
  })
end, 'search scene accepted invalid result index')

h.assert_true(not search_scene.goto_first(instance), 'goto_first reported movement without a window', scope)
h.assert_true(not search_scene.goto_offset(instance, 1), 'goto_offset reported movement without a window', scope)
assert_fails(function()
  search_scene.goto_offset(instance, 1.5)
end, 'search scene accepted fractional navigation step')
assert_fails(function()
  search_scene.open_detail({
    state = instance.state,
  })
end, 'search scene accepted missing rerender callback')
h.assert_true(not search_scene.open_detail(instance), 'open_detail reported success without a window', scope)

assert_fails(function()
  search_scene.handle(instance, '')
end, 'search scene accepted empty action')
local ok, err = search_scene.handle(instance, 'open_detail')
h.assert_true(not ok, 'open_detail action succeeded without a window', scope)
h.assert_true(err == nil, 'open_detail action reported an unexpected error', scope)
local activate_ok, activate_err = search_scene.handle(instance, 'activate')
h.assert_true(not activate_ok, 'activate action succeeded without a window', scope)
h.assert_true(activate_err == nil, 'activate action reported an unexpected error', scope)

print('hlcraft ui search scene: OK')
