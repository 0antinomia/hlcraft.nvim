local h = require('tests.helpers')
local scope = 'hlcraft ui search scene'

local search_scene = require('hlcraft.ui.scene.search')
local ui_state = require('hlcraft.ui.state')

local assert_fails = h.scoped_assert_fails(scope)

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
h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'result' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local sparse_current_entry_ok = pcall(search_scene.current_entry, {
    state = {
      buf = buf,
      geometry = vim.tbl_extend('force', ui_state.geometry(), {
        result_lines = {
          [1] = 2,
        },
      }),
      results = {
        [2] = { name = 'Late' },
      },
    },
  })
  h.assert_true(not sparse_current_entry_ok, 'search scene accepted sparse results', scope)
end, { current = true })
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
  search_scene.update_results({
    state = {
      name_query = '',
      color_query = '',
      list_cursor = 0,
    },
  })
end, 'search scene accepted invalid list cursor state')
local invalid_cursor_instance = {
  state = {
    name_query = '',
    color_query = '',
    list_cursor = 0,
    results = {
      { name = 'Preserved' },
    },
  },
}
assert_fails(function()
  search_scene.update_results(invalid_cursor_instance)
end, 'search scene accepted invalid list cursor state before updating results')
h.assert_equal(
  invalid_cursor_instance.state.results[1].name,
  'Preserved',
  'failed search update changed result state',
  scope
)
assert_fails(function()
  search_scene.rows({
    state = {
      results = {
        { name = 'Only' },
      },
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
      results = {
        { name = 'Only' },
      },
      geometry = {
        result_lines = {
          [1] = math.huge,
        },
      },
    },
  })
end, 'search scene accepted invalid result index')
assert_fails(function()
  search_scene.rows({
    state = {
      results = {
        { name = 'Only' },
      },
      geometry = {
        result_lines = {
          [1] = 2,
        },
      },
    },
  })
end, 'search scene accepted result geometry outside result range')

h.with_temp_buf(function(buf)
  local stale_instance = {
    state = {
      buf = buf,
      field_editor = ui_state.field_editor(),
      geometry = vim.tbl_extend('force', ui_state.geometry(), {
        detail_menu = {},
        result_lines = {
          [1] = 2,
        },
      }),
      last_workspace_win = vim.api.nvim_get_current_win(),
      results = {
        { name = 'Only' },
      },
    },
    rerender = function() end,
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'stale' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  assert_fails(function()
    search_scene.current_entry(stale_instance)
  end, 'search current entry accepted result geometry outside result range')
  assert_fails(function()
    search_scene.open_detail(stale_instance)
  end, 'search open_detail accepted result geometry outside result range')
  h.assert_true(stale_instance.state.detail_index == nil, 'failed open_detail changed detail index', scope)
end, { current = true })

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
