local h = require('tests.helpers')
local scope = 'hlcraft ui search scene'

local search_scene = require('hlcraft.ui.scene.search')
local ui_state = require('hlcraft.ui.state')

-- Registers built-in scenes used by open_detail().
require('hlcraft.ui.instance')

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

h.with_temp_buf(function(buf)
  local back_failure_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-search-back-failure-test'),
    state = ui_state.initial(),
  }
  back_failure_instance.state.buf = buf
  local original_buf_delete = vim.api.nvim_buf_delete
  vim.api.nvim_buf_delete = function(target_buf, ...)
    if target_buf == buf then
      error('workspace delete failed')
    end
    return original_buf_delete(target_buf, ...)
  end
  local notifications = {}
  local back_ok, back_err
  local back_stub_ok, back_stub_err = xpcall(function()
    back_ok, back_err = h.with_notify_stub(function()
      return search_scene.back(back_failure_instance)
    end, function(message)
      notifications[#notifications + 1] = message
    end)
  end, debug.traceback)
  vim.api.nvim_buf_delete = original_buf_delete
  if not back_stub_ok then
    error(back_stub_err, 0)
  end
  h.assert_equal(back_ok, false, 'search scene back ignored failed workspace close', scope)
  h.assert_true(back_err == nil, 'search scene back returned an unexpected close error', scope)
  h.assert_true(
    notifications[1] and notifications[1]:find('workspace buffer', 1, true) ~= nil,
    'search scene back did not preserve close failure notification',
    scope
  )
  h.assert_equal(
    back_failure_instance.state.buf,
    buf,
    'search scene failed back dropped workspace buffer handle',
    scope
  )
end)

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

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    'search row',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    'detail row',
  })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local detail_jump_instance = {
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
      list_cursor = 1,
      results = {
        { name = 'First' },
        { name = 'Second' },
      },
      scene = ui_state.search_scene(),
    },
    rerender = function(self)
      self.state.geometry = vim.tbl_extend('force', ui_state.geometry(), {
        detail_menu = {
          group = {
            line = 9,
            key = 'group',
          },
        },
      })
    end,
  }

  h.assert_true(search_scene.open_detail(detail_jump_instance), 'open_detail did not enter detail view', scope)
  h.assert_equal(detail_jump_instance.state.list_cursor, 2, 'open_detail did not sync list cursor', scope)
  h.assert_equal(
    vim.api.nvim_win_get_cursor(0)[1],
    9,
    'open_detail did not jump using the rendered detail geometry',
    scope
  )
end, { current = true })

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'search row' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local render_failure_instance = {
    state = {
      buf = buf,
      detail_index = nil,
      field_editor = { field = 'fg' },
      geometry = vim.tbl_extend('force', ui_state.geometry(), {
        result_lines = {
          [1] = 2,
        },
      }),
      last_workspace_win = vim.api.nvim_get_current_win(),
      list_cursor = 1,
      results = {
        { name = 'First' },
        { name = 'Second' },
      },
      scene = ui_state.search_scene(),
    },
    rerender = function()
      error('render failed')
    end,
  }

  local render_failure_ok = pcall(search_scene.open_detail, render_failure_instance)
  h.assert_true(not render_failure_ok, 'open_detail accepted failed detail render', scope)
  h.assert_equal(render_failure_instance.state.list_cursor, 1, 'failed open_detail changed list cursor', scope)
  h.assert_true(render_failure_instance.state.detail_index == nil, 'failed open_detail changed detail index', scope)
  h.assert_equal(
    render_failure_instance.state.field_editor.field,
    'fg',
    'failed open_detail changed field editor',
    scope
  )
  h.assert_equal(render_failure_instance.state.scene.name, 'search', 'failed open_detail changed scene', scope)
end, { current = true })

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'search row' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local partial_render_failure_count = 0
  local partial_render_failure_instance = {
    state = {
      buf = buf,
      detail_index = nil,
      field_editor = ui_state.field_editor(),
      geometry = vim.tbl_extend('force', ui_state.geometry(), {
        result_lines = {
          [1] = 1,
        },
      }),
      last_workspace_win = vim.api.nvim_get_current_win(),
      list_cursor = 1,
      results = {
        { name = 'Only' },
      },
      scene = ui_state.search_scene(),
    },
    rerender = function(self)
      partial_render_failure_count = partial_render_failure_count + 1
      if self.state.scene.name == 'detail' then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'broken detail' })
        error('detail render failed')
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'restored search' })
    end,
  }

  local partial_render_failure_ok = pcall(search_scene.open_detail, partial_render_failure_instance)
  h.assert_true(not partial_render_failure_ok, 'open_detail accepted partial render failure', scope)
  h.assert_equal(partial_render_failure_count, 2, 'partial-failed open_detail did not rerender restored state', scope)
  h.assert_equal(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
    'restored search',
    'partial-failed open_detail left rendered detail content',
    scope
  )
  h.assert_true(
    partial_render_failure_instance.state.detail_index == nil,
    'partial-failed open_detail changed detail index',
    scope
  )
  h.assert_equal(
    partial_render_failure_instance.state.scene.name,
    'search',
    'partial-failed open_detail changed scene',
    scope
  )
end, { current = true })

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'search row' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local restore_render_failure_instance = {
    state = {
      buf = buf,
      detail_index = nil,
      field_editor = ui_state.field_editor(),
      geometry = vim.tbl_extend('force', ui_state.geometry(), {
        result_lines = {
          [1] = 1,
        },
      }),
      last_workspace_win = vim.api.nvim_get_current_win(),
      list_cursor = 1,
      results = {
        { name = 'Only' },
      },
      scene = ui_state.search_scene(),
    },
    rerender = function(self)
      if self.state.scene.name == 'detail' then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'broken detail' })
        error('detail render failed')
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'restore failed' })
      error('restore render failed')
    end,
  }

  local restore_render_failure_ok, restore_render_failure_err =
    pcall(search_scene.open_detail, restore_render_failure_instance)
  h.assert_true(not restore_render_failure_ok, 'open_detail accepted failed restore render', scope)
  h.assert_true(
    tostring(restore_render_failure_err):find('restore render failed', 1, true) ~= nil,
    'open_detail restore render failure did not report restore error',
    scope
  )
  h.assert_true(
    restore_render_failure_instance.state.detail_index == nil,
    'restore-render-failed open_detail changed detail index',
    scope
  )
  h.assert_equal(
    restore_render_failure_instance.state.scene.name,
    'search',
    'restore-render-failed open_detail changed scene',
    scope
  )
end, { current = true })

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'search row' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local jump_failure_instance = {
    state = {
      buf = buf,
      detail_index = nil,
      field_editor = ui_state.field_editor(),
      geometry = vim.tbl_extend('force', ui_state.geometry(), {
        result_lines = {
          [1] = 1,
        },
      }),
      last_workspace_win = vim.api.nvim_get_current_win(),
      list_cursor = 1,
      results = {
        { name = 'Only' },
      },
      scene = ui_state.search_scene(),
    },
    rerender = function(self)
      if self.state.scene.name == 'detail' then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'detail row' })
        self.state.geometry = vim.tbl_extend('force', ui_state.geometry(), {
          detail_menu = {
            group = {
              line = 9,
              key = 'group',
            },
          },
        })
      else
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'search row' })
        self.state.geometry = vim.tbl_extend('force', ui_state.geometry(), {
          result_lines = {
            [1] = 1,
          },
        })
      end
    end,
  }

  local jump_failure_ok = pcall(search_scene.open_detail, jump_failure_instance)
  h.assert_true(not jump_failure_ok, 'open_detail accepted failed detail jump', scope)
  h.assert_true(jump_failure_instance.state.detail_index == nil, 'jump-failed open_detail changed detail index', scope)
  h.assert_equal(jump_failure_instance.state.scene.name, 'search', 'jump-failed open_detail changed scene', scope)
  h.assert_equal(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1],
    'search row',
    'jump-failed open_detail kept rendered detail content',
    scope
  )
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
