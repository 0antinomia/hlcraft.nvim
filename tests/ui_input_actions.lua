local h = require('tests.helpers')
local scope = 'hlcraft ui input actions'

local actions = require('hlcraft.ui.input.actions')
local input_model = require('hlcraft.ui.input.model')
local ui_state = require('hlcraft.ui.state')

local function input_namespace(instance)
  return instance.input_ns or instance.ns
end

local function set_input_marks(instance, name, start_row, end_boundary_row)
  local ns = input_namespace(instance)
  instance.state.extmark_ids[name .. ':start'] = vim.api.nvim_buf_set_extmark(instance.state.buf, ns, start_row, 0, {
    right_gravity = false,
  })
  instance.state.extmark_ids[name .. ':end'] =
    vim.api.nvim_buf_set_extmark(instance.state.buf, ns, end_boundary_row, 0, {
      right_gravity = false,
    })
end

h.with_temp_buf(function(buf)
  local instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-input-actions-test'),
    input_ns = vim.api.nvim_create_namespace('hlcraft-ui-input-actions-input-test'),
    state = {
      buf = buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
    },
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'alpha', '', 'color', 'detail', 'after' })
  instance.state.geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
    { name = 'color', kind = 'color', line = 3 },
    { name = 'fg', kind = 'detail', line = 4 },
  }
  set_input_marks(instance, 'name', 0, 2)
  set_input_marks(instance, 'color', 2, 3)
  set_input_marks(instance, 'fg', 3, 4)

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  h.assert_true(actions.should_block_backward_delete(instance), 'input start did not block backward delete', scope)

  vim.api.nvim_win_set_cursor(0, { 1, 1 })
  h.assert_true(not actions.should_block_backward_delete(instance), 'input interior blocked backward delete', scope)

  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  h.assert_true(actions.should_block_forward_delete(instance), 'input end did not block forward delete', scope)

  vim.api.nvim_win_set_cursor(0, { 1, 1 })
  h.assert_true(not actions.should_block_forward_delete(instance), 'input interior blocked forward delete', scope)

  vim.api.nvim_win_set_cursor(0, { 5, 0 })
  h.assert_true(not actions.should_block_backward_delete(instance), 'outside input blocked backward delete', scope)
  h.assert_true(not actions.should_block_forward_delete(instance), 'outside input blocked forward delete', scope)

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  actions.goto_next_input(instance)
  h.assert_equal(vim.api.nvim_win_get_cursor(0)[1], 3, 'next input did not jump to color', scope)

  actions.goto_next_input(instance)
  h.assert_equal(vim.api.nvim_win_get_cursor(0)[1], 4, 'next input did not jump to detail', scope)

  actions.goto_prev_input(instance)
  h.assert_equal(vim.api.nvim_win_get_cursor(0)[1], 3, 'previous input did not jump to color', scope)

  instance.state.detail_index = 1
  actions.goto_first_input(instance)
  h.assert_equal(vim.api.nvim_win_get_cursor(0)[1], 4, 'detail scene first input did not prefer detail rows', scope)

  h.assert_equal(input_model.get_input_value(instance, 'name'), 'alpha ', 'input value did not normalize lines', scope)
  h.assert_true(input_model.remove_trailing_empty_line(instance, 'name'), 'trailing empty line was not removed', scope)
  h.assert_equal(
    input_model.get_input_value(instance, 'name'),
    'alpha',
    'trailing line cleanup kept stale input value',
    scope
  )
  h.assert_true(
    not input_model.remove_trailing_empty_line(instance, 'name'),
    'single physical input line was removed',
    scope
  )

  local fill_failure_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local original_buf_set_lines = vim.api.nvim_buf_set_lines
  local fill_set_lines_calls = 0
  vim.api.nvim_buf_set_lines = function(target_buf, ...)
    fill_set_lines_calls = fill_set_lines_calls + 1
    if target_buf == buf and fill_set_lines_calls == 2 then
      error('fill boundary delete failed')
    end
    return original_buf_set_lines(target_buf, ...)
  end
  local fill_failure_ok = pcall(input_model.fill_input, instance, 'name', 'next', true)
  vim.api.nvim_buf_set_lines = original_buf_set_lines
  h.assert_true(not fill_failure_ok, 'fill_input accepted partial buffer write failure', scope)
  h.assert_true(
    vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), fill_failure_lines),
    'failed fill_input changed buffer lines',
    scope
  )
  h.assert_equal(input_model.get_input_value(instance, 'name'), 'alpha', 'failed fill_input changed input value', scope)

  local rollback_failure_original_set_lines = vim.api.nvim_buf_set_lines
  local rollback_failure_calls = 0
  vim.api.nvim_buf_set_lines = function(target_buf, ...)
    rollback_failure_calls = rollback_failure_calls + 1
    if target_buf == buf and rollback_failure_calls == 2 then
      error('fill boundary delete failed')
    end
    if target_buf == buf and rollback_failure_calls == 3 then
      error('fill rollback failed')
    end
    return rollback_failure_original_set_lines(target_buf, ...)
  end
  local rollback_failure_ok, rollback_failure_err = pcall(input_model.fill_input, instance, 'name', 'next', true)
  vim.api.nvim_buf_set_lines = rollback_failure_original_set_lines
  h.assert_true(not rollback_failure_ok, 'fill_input accepted failed rollback after partial write', scope)
  h.assert_true(
    tostring(rollback_failure_err):find('fill rollback failed', 1, true) ~= nil,
    'fill_input rollback failure did not report the line restore error',
    scope
  )
  rollback_failure_original_set_lines(buf, 0, -1, false, fill_failure_lines)
  set_input_marks(instance, 'name', 0, 1)
  set_input_marks(instance, 'color', 2, 3)
  set_input_marks(instance, 'fg', 3, 4)

  local normalize_ok, normalize_err = pcall(input_model.normalize_single_line, 123)
  h.assert_true(not normalize_ok, 'single-line normalization accepted a non-string value', scope)
  h.assert_true(
    tostring(normalize_err):find('input value must be a string', 1, true) ~= nil,
    'single-line normalization error changed',
    scope
  )

  local fill_ok, fill_err = pcall(input_model.fill_input, instance, 'name', 123, true)
  h.assert_true(not fill_ok, 'fill_input accepted a non-string value', scope)
  h.assert_true(
    tostring(fill_err):find('input value must be a string', 1, true) ~= nil,
    'fill_input type error changed',
    scope
  )
  local invalid_clear_old_ok = pcall(input_model.fill_input, instance, 'name', nil, 'yes')
  h.assert_true(not invalid_clear_old_ok, 'fill_input accepted non-boolean clear flag', scope)

  local sync_failure_instance = {
    ns = instance.ns,
    input_ns = instance.input_ns,
    state = {
      buf = buf,
      color_query = 'old color',
      detail_index = nil,
      extmark_ids = vim.deepcopy(instance.state.extmark_ids),
      geometry = vim.deepcopy(instance.state.geometry),
      name_query = 'old name',
      rendering = false,
    },
  }
  sync_failure_instance.state.extmark_ids['color:start'] = false
  local sync_failure_ok = pcall(input_model.sync_queries_from_buffer, sync_failure_instance)
  h.assert_true(not sync_failure_ok, 'sync_queries_from_buffer accepted invalid color extmark', scope)
  h.assert_equal(sync_failure_instance.state.name_query, 'old name', 'failed query sync changed name query', scope)
  h.assert_equal(sync_failure_instance.state.color_query, 'old color', 'failed query sync changed color query', scope)

  h.assert_true(not input_model.fill_input(instance, 'name', nil, false), 'nil fill without clear changed input', scope)
  h.assert_true(input_model.fill_input(instance, 'name', nil, true), 'nil fill with clear did not report change', scope)
  h.assert_equal(input_model.get_input_value(instance, 'name'), '', 'nil fill with clear did not empty input', scope)

  local invalid_input_name_ok = pcall(input_model.get_input_value, instance, '')
  h.assert_true(not invalid_input_name_ok, 'input model accepted an empty input name', scope)
  local invalid_input_row_ok = pcall(input_model.get_input_at_row, instance, -1)
  h.assert_true(not invalid_input_row_ok, 'input model accepted a negative row', scope)
  local invalid_current_area_row_ok = pcall(input_model.current_area, instance, 0)
  h.assert_true(not invalid_current_area_row_ok, 'input model accepted a zero current-area row', scope)
  local missing_result_lines_ok = pcall(input_model.current_area, {
    state = {
      geometry = {
        inputs = {},
      },
    },
  }, 1)
  h.assert_true(not missing_result_lines_ok, 'input model accepted missing result line geometry', scope)
  local invalid_result_index_ok = pcall(input_model.current_area, {
    state = {
      geometry = {
        inputs = {},
        result_lines = {
          [1] = 0,
        },
      },
    },
  }, 1)
  h.assert_true(not invalid_result_index_ok, 'input model accepted invalid result index geometry', scope)
  local missing_set_extmark_instance_ok = pcall(input_model.set_input_extmarks, nil)
  h.assert_true(not missing_set_extmark_instance_ok, 'input model accepted missing extmark instance', scope)
  local invalid_extmark_namespace_ok = pcall(input_model.set_input_extmarks, {
    ns = false,
    state = {
      buf = buf,
      geometry = {
        inputs = {
          { name = 'bad', kind = 'name', line = 1 },
        },
      },
    },
  })
  h.assert_true(not invalid_extmark_namespace_ok, 'input model accepted invalid extmark namespace', scope)
  local invalid_extmark_line_ok = pcall(input_model.set_input_extmarks, {
    ns = instance.ns,
    state = {
      buf = buf,
      geometry = {
        inputs = {
          { name = 'bad', kind = 'name', line = 0 },
        },
      },
    },
  })
  h.assert_true(not invalid_extmark_line_ok, 'input model accepted invalid extmark row', scope)
  local previous_extmark_ids = instance.state.extmark_ids
  local expected_extmark_ids = vim.deepcopy(previous_extmark_ids)
  local input_ns = input_namespace(instance)
  local previous_extmark_count = #vim.api.nvim_buf_get_extmarks(buf, input_ns, 0, -1, {})
  local previous_name_mark = vim.api.nvim_buf_get_extmark_by_id(buf, input_ns, previous_extmark_ids['name:start'], {})
  local original_set_extmark = vim.api.nvim_buf_set_extmark
  local set_extmark_calls = 0
  vim.api.nvim_buf_set_extmark = function(...)
    set_extmark_calls = set_extmark_calls + 1
    if set_extmark_calls == 2 then
      error('extmark failed')
    end
    return original_set_extmark(...)
  end
  local failed_extmark_refresh_ok = pcall(input_model.set_input_extmarks, instance)
  vim.api.nvim_buf_set_extmark = original_set_extmark
  h.assert_true(not failed_extmark_refresh_ok, 'input extmark refresh accepted failed extmark creation', scope)
  h.assert_equal(
    instance.state.extmark_ids,
    previous_extmark_ids,
    'failed input extmark refresh replaced extmark state',
    scope
  )
  h.assert_true(
    vim.deep_equal(instance.state.extmark_ids, expected_extmark_ids),
    'failed input extmark refresh changed extmark values',
    scope
  )
  h.assert_equal(
    #vim.api.nvim_buf_get_extmarks(buf, input_ns, 0, -1, {}),
    previous_extmark_count,
    'failed input extmark refresh leaked new extmarks',
    scope
  )
  local preserved_name_mark = vim.api.nvim_buf_get_extmark_by_id(buf, input_ns, previous_extmark_ids['name:start'], {})
  h.assert_true(
    vim.deep_equal(preserved_name_mark, previous_name_mark),
    'failed input extmark refresh moved old extmarks',
    scope
  )
  local invalid_pos_namespace_ok = pcall(input_model.get_input_pos, {
    ns = false,
    state = instance.state,
  }, 'color')
  h.assert_true(not invalid_pos_namespace_ok, 'input model accepted invalid position namespace', scope)
  local invalid_field_line_ok = pcall(input_model.field_line_text, instance, { line = 0 })
  h.assert_true(not invalid_field_line_ok, 'input model accepted invalid field line', scope)
  local invalid_field_shape_ok = pcall(input_model.field_line_text, instance, false)
  h.assert_true(not invalid_field_shape_ok, 'input model accepted invalid field shape', scope)
  local missing_action_instance_ok = pcall(actions.should_block_backward_delete, nil)
  h.assert_true(not missing_action_instance_ok, 'input actions accepted missing instance', scope)
  local missing_action_geometry_ok = pcall(actions.should_block_backward_delete, {
    ns = instance.ns,
    state = {
      buf = buf,
      extmark_ids = {},
    },
  })
  h.assert_true(not missing_action_geometry_ok, 'input actions accepted missing geometry', scope)
  local invalid_paste_below_visual_ok = pcall(actions.paste_below, instance, nil)
  h.assert_true(not invalid_paste_below_visual_ok, 'paste below accepted missing visual flag', scope)
  local invalid_paste_above_visual_ok = pcall(actions.paste_above, instance, 'visual')
  h.assert_true(not invalid_paste_above_visual_ok, 'paste above accepted non-boolean visual flag', scope)
  local invalid_first_geometry_ok = pcall(actions.goto_first_input, { state = { geometry = {} } })
  h.assert_true(not invalid_first_geometry_ok, 'first input jump accepted missing geometry inputs', scope)
  local non_sequence_first_geometry_ok = pcall(actions.goto_first_input, {
    state = {
      geometry = {
        inputs = {
          [2] = { name = 'late', kind = 'name', line = 1 },
        },
      },
    },
  })
  h.assert_true(not non_sequence_first_geometry_ok, 'first input jump accepted non-sequence geometry inputs', scope)
  local invalid_first_detail_ok =
    pcall(actions.goto_first_input, { state = { geometry = instance.state.geometry, detail_index = 0 } })
  h.assert_true(not invalid_first_detail_ok, 'first input jump accepted invalid detail index', scope)
  local missing_extmarks_ok = pcall(input_model.get_input_pos, {
    state = {
      geometry = instance.state.geometry,
    },
  }, 'name')
  h.assert_true(not missing_extmarks_ok, 'input model accepted missing extmark ids', scope)
  local invalid_extmark_id_ok = pcall(input_model.get_input_pos, {
    ns = instance.ns,
    state = vim.tbl_extend('force', instance.state, {
      extmark_ids = {
        ['name:start'] = false,
        ['name:end'] = instance.state.extmark_ids['name:end'],
      },
    }),
  }, 'name')
  h.assert_true(not invalid_extmark_id_ok, 'input model accepted invalid extmark id', scope)
end, { current = true })

h.with_temp_buf(function(buf)
  local scheduled_cleanup
  local original_schedule = vim.schedule
  vim.schedule = function(callback)
    scheduled_cleanup = callback
  end

  local instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-input-actions-paste-cleanup-test'),
    input_ns = vim.api.nvim_create_namespace('hlcraft-ui-input-actions-paste-cleanup-input-test'),
    state = {
      buf = buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
    },
  }
  instance.state.geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '', '' })
  set_input_marks(instance, 'name', 0, 1)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  actions.paste_below(instance, false)
  vim.schedule = original_schedule
  h.assert_true(type(scheduled_cleanup) == 'function', 'paste below did not schedule trailing cleanup', scope)
  vim.api.nvim_buf_delete(buf, { force = true })
  local cleanup_ok = pcall(scheduled_cleanup)
  h.assert_true(cleanup_ok, 'scheduled paste cleanup failed after buffer deletion', scope)
end, { current = true })

h.with_temp_buf(function(buf)
  local scheduled_cleanup
  local original_schedule = vim.schedule
  vim.schedule = function(callback)
    scheduled_cleanup = callback
  end

  local instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-input-actions-stale-cleanup-test'),
    input_ns = vim.api.nvim_create_namespace('hlcraft-ui-input-actions-stale-cleanup-input-test'),
    state = {
      buf = buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
    },
  }
  instance.state.geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '', '' })
  set_input_marks(instance, 'name', 0, 1)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  actions.paste_below(instance, false)
  vim.schedule = original_schedule
  h.assert_true(type(scheduled_cleanup) == 'function', 'paste below did not schedule stale cleanup', scope)
  instance.state.extmark_ids = {}
  instance.state.geometry.inputs = {
    { name = 'color', kind = 'color', line = 1 },
  }
  set_input_marks(instance, 'color', 0, 2)
  local cleanup_ok = pcall(scheduled_cleanup)
  h.assert_true(cleanup_ok, 'stale scheduled paste cleanup failed', scope)
  h.assert_equal(
    vim.api.nvim_buf_line_count(buf),
    2,
    'stale scheduled paste cleanup deleted a different input line',
    scope
  )
end, { current = true })

local invalid_geometry_ok = pcall(input_model.get_input_at_row, {
  state = {
    geometry = {},
  },
}, 0)
h.assert_true(not invalid_geometry_ok, 'input model accepted missing geometry inputs', scope)
local non_sequence_geometry_ok = pcall(input_model.get_input_at_row, {
  state = {
    geometry = {
      inputs = {
        [2] = { name = 'late', kind = 'name', line = 1 },
      },
    },
  },
}, 0)
h.assert_true(not non_sequence_geometry_ok, 'input model accepted non-sequence geometry inputs', scope)
local invalid_instance_ok = pcall(input_model.get_input_at_row, nil, 0)
h.assert_true(not invalid_instance_ok, 'input model accepted missing instance', scope)

print('hlcraft ui input actions: OK')
