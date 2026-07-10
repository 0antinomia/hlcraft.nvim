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

local assert_fails = h.scoped_assert_fails(scope)

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

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'first', '', 'second' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local navigation_instance = {
    state = {
      buf = buf,
      geometry = vim.tbl_extend('force', ui_state.geometry(), {
        result_lines = {
          [1] = 1,
          [3] = 2,
        },
      }),
      last_workspace_win = vim.api.nvim_get_current_win(),
      list_cursor = 1,
    },
  }

  h.assert_true(navigation.move_interactive(navigation_instance, 1), 'navigation did not move to next result', scope)
  h.assert_equal(navigation_instance.state.list_cursor, 2, 'navigation did not sync list cursor after move', scope)
  h.assert_equal(vim.api.nvim_win_get_cursor(0)[1], 3, 'navigation did not move to next result row', scope)

  h.assert_true(navigation.jump_to_row(navigation_instance, 1, false), 'navigation did not jump to first result', scope)
  h.assert_equal(navigation_instance.state.list_cursor, 1, 'navigation did not sync list cursor after jump', scope)
  h.assert_equal(vim.api.nvim_win_get_cursor(0)[1], 1, 'navigation did not jump to first result row', scope)

  navigation_instance.state.list_cursor = 2
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  h.assert_true(navigation.clamp_cursor(navigation_instance), 'navigation did not clamp to a result row', scope)
  h.assert_equal(navigation_instance.state.list_cursor, 1, 'navigation did not sync list cursor after clamp', scope)
  h.assert_equal(vim.api.nvim_win_get_cursor(0)[1], 1, 'navigation did not clamp to first result row', scope)

  navigation_instance.state.list_cursor = 1
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  h.assert_true(
    not navigation.clamp_cursor(navigation_instance),
    'navigation moved an already allowed result row',
    scope
  )
  h.assert_equal(navigation_instance.state.list_cursor, 2, 'navigation did not sync list cursor on allowed row', scope)

  navigation_instance.state.geometry.result_lines = {
    [3] = 0,
  }
  navigation_instance.state.list_cursor = 1
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local failed_jump_ok = pcall(navigation.jump_to_row, navigation_instance, 3, false)
  h.assert_true(not failed_jump_ok, 'navigation accepted invalid result index while jumping', scope)
  h.assert_equal(vim.api.nvim_win_get_cursor(0)[1], 1, 'failed navigation jump moved cursor', scope)
  h.assert_equal(navigation_instance.state.list_cursor, 1, 'failed navigation jump changed list cursor', scope)

  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  local failed_clamp_ok = pcall(navigation.clamp_cursor, navigation_instance)
  h.assert_true(not failed_clamp_ok, 'navigation clamp accepted invalid result index', scope)
  h.assert_equal(vim.api.nvim_win_get_cursor(0)[1], 2, 'failed navigation clamp moved cursor', scope)
  h.assert_equal(navigation_instance.state.list_cursor, 1, 'failed navigation clamp changed list cursor', scope)
end, { current = true })

h.with_temp_buf(function(workspace_buf)
  local origin_win = vim.api.nvim_get_current_win()
  local workspace_win
  local ok, err = xpcall(function()
    vim.api.nvim_buf_set_lines(workspace_buf, 0, -1, false, { 'only' })
    vim.cmd('vsplit')
    workspace_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(workspace_win, workspace_buf)
    vim.api.nvim_set_current_win(origin_win)

    local navigation_instance = {
      state = {
        buf = workspace_buf,
        geometry = ui_state.geometry(),
        last_workspace_win = workspace_win,
        list_cursor = 1,
      },
    }

    local failed_window_jump_ok = pcall(navigation.jump_to_row, navigation_instance, 3, false)
    h.assert_true(not failed_window_jump_ok, 'navigation accepted out-of-range window jump', scope)
    h.assert_equal(vim.api.nvim_get_current_win(), origin_win, 'failed navigation jump changed current window', scope)
    h.assert_equal(
      vim.api.nvim_win_get_cursor(workspace_win)[1],
      1,
      'failed navigation jump moved workspace cursor',
      scope
    )
  end, debug.traceback)
  if workspace_win and vim.api.nvim_win_is_valid(workspace_win) then
    pcall(vim.api.nvim_win_close, workspace_win, true)
  end
  if vim.api.nvim_win_is_valid(origin_win) then
    vim.api.nvim_set_current_win(origin_win)
  end
  if not ok then
    error(err, 0)
  end
end)

h.with_temp_buf(function(workspace_buf)
  local origin_win = vim.api.nvim_get_current_win()
  local workspace_win
  local ok, err = xpcall(function()
    vim.api.nvim_buf_set_lines(workspace_buf, 0, -1, false, { 'first', 'second' })
    vim.cmd('vsplit')
    workspace_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(workspace_win, workspace_buf)
    vim.api.nvim_win_set_cursor(workspace_win, { 1, 0 })
    vim.api.nvim_set_current_win(origin_win)

    local navigation_instance = {
      state = {
        buf = workspace_buf,
        geometry = vim.tbl_extend('force', ui_state.geometry(), {
          result_lines = {
            [2] = 2,
          },
        }),
        last_workspace_win = workspace_win,
        list_cursor = 1,
      },
    }

    local original_win_set_cursor = vim.api.nvim_win_set_cursor
    vim.api.nvim_win_set_cursor = function(target_win, ...)
      if target_win == workspace_win then
        error('cursor failed')
      end
      return original_win_set_cursor(target_win, ...)
    end
    local failed_cursor_jump_ok = pcall(navigation.jump_to_row, navigation_instance, 2, false)
    vim.api.nvim_win_set_cursor = original_win_set_cursor

    h.assert_true(not failed_cursor_jump_ok, 'navigation accepted failed cursor jump', scope)
    h.assert_equal(vim.api.nvim_get_current_win(), origin_win, 'failed cursor jump changed current window', scope)
    h.assert_equal(vim.api.nvim_win_get_cursor(workspace_win)[1], 1, 'failed cursor jump moved workspace cursor', scope)
    h.assert_equal(navigation_instance.state.list_cursor, 1, 'failed cursor jump changed list cursor', scope)
  end, debug.traceback)
  if workspace_win and vim.api.nvim_win_is_valid(workspace_win) then
    pcall(vim.api.nvim_win_close, workspace_win, true)
  end
  if vim.api.nvim_win_is_valid(origin_win) then
    vim.api.nvim_set_current_win(origin_win)
  end
  if not ok then
    error(err, 0)
  end
end)

h.with_temp_buf(function(workspace_buf)
  local origin_win = vim.api.nvim_get_current_win()
  local workspace_win
  local original_cmd = vim.cmd
  local original_win_set_cursor = vim.api.nvim_win_set_cursor
  local ok, err = xpcall(function()
    vim.api.nvim_buf_set_lines(workspace_buf, 0, -1, false, { 'first', 'second' })
    vim.cmd('vsplit')
    workspace_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(workspace_win, workspace_buf)
    vim.api.nvim_win_set_cursor(workspace_win, { 1, 0 })
    vim.api.nvim_set_current_win(origin_win)

    local navigation_instance = {
      state = {
        buf = workspace_buf,
        geometry = vim.tbl_extend('force', ui_state.geometry(), {
          result_lines = {
            [2] = 2,
          },
        }),
        last_workspace_win = workspace_win,
        list_cursor = 1,
      },
    }

    vim.cmd = function(command)
      if command == 'startinsert!' then
        error('insert failed')
      end
      return original_cmd(command)
    end
    vim.api.nvim_win_set_cursor = function(target_win, cursor)
      if target_win == workspace_win and cursor[1] == 1 then
        error('cursor rollback failed')
      end
      return original_win_set_cursor(target_win, cursor)
    end
    local rollback_failure_ok, rollback_failure_err = pcall(navigation.jump_to_row, navigation_instance, 2, true)
    vim.cmd = original_cmd
    vim.api.nvim_win_set_cursor = original_win_set_cursor

    h.assert_true(not rollback_failure_ok, 'navigation accepted failed insert with failed rollback', scope)
    h.assert_true(
      tostring(rollback_failure_err):find('cursor rollback failed', 1, true) ~= nil,
      'navigation rollback failure did not report cursor restore error',
      scope
    )
    h.assert_equal(vim.api.nvim_get_current_win(), origin_win, 'failed rollback changed current window', scope)
    h.assert_equal(navigation_instance.state.list_cursor, 1, 'failed rollback changed list cursor', scope)
  end, debug.traceback)
  vim.cmd = original_cmd
  vim.api.nvim_win_set_cursor = original_win_set_cursor
  if workspace_win and vim.api.nvim_win_is_valid(workspace_win) then
    pcall(vim.api.nvim_win_close, workspace_win, true)
  end
  if vim.api.nvim_win_is_valid(origin_win) then
    vim.api.nvim_set_current_win(origin_win)
  end
  if not ok then
    error(err, 0)
  end
end)

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
