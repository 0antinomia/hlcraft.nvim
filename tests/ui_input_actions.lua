local h = require('tests.helpers')
local scope = 'hlcraft ui input actions'

local actions = require('hlcraft.ui.input.actions')
local input_model = require('hlcraft.ui.input.model')
local ui_state = require('hlcraft.ui.state')

local function set_input_marks(instance, name, start_row, end_boundary_row)
  instance.state.extmark_ids[name .. ':start'] =
    vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, start_row, 0, {
      right_gravity = false,
    })
  instance.state.extmark_ids[name .. ':end'] =
    vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, end_boundary_row, 0, {
      right_gravity = false,
    })
end

h.with_temp_buf(function(buf)
  local instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-input-actions-test'),
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

  h.assert_true(not input_model.fill_input(instance, 'name', nil, false), 'nil fill without clear changed input', scope)
  h.assert_true(input_model.fill_input(instance, 'name', nil, true), 'nil fill with clear did not report change', scope)
  h.assert_equal(input_model.get_input_value(instance, 'name'), '', 'nil fill with clear did not empty input', scope)
end, { current = true })

print('hlcraft ui input actions: OK')
