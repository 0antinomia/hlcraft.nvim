local h = require('tests.helpers')
local scope = 'hlcraft ui render buffer'

local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local render_buffer = require('hlcraft.ui.render.buffer')
local theme = require('hlcraft.ui.theme')
local ui_state = require('hlcraft.ui.state')

local invalid_input_extra_ok = pcall(render_buffer.new_input_field, 'name', 'name', 1, false)
h.assert_true(not invalid_input_extra_ok, 'input field helper accepted non-table extra options', scope)
local invalid_input_name_ok = pcall(render_buffer.new_input_field, '', 'name', 1)
h.assert_true(not invalid_input_name_ok, 'input field helper accepted an empty name', scope)
local invalid_input_kind_ok = pcall(render_buffer.new_input_field, 'name', false, 1)
h.assert_true(not invalid_input_kind_ok, 'input field helper accepted a non-string kind', scope)
local invalid_input_line_ok = pcall(render_buffer.new_input_field, 'name', 'name', 0)
h.assert_true(not invalid_input_line_ok, 'input field helper accepted an invalid line', scope)
local missing_input_width_ok = pcall(render_buffer.append_input, {}, { inputs = {} }, 'name', 'name', 'value', {})
h.assert_true(not missing_input_width_ok, 'input append helper accepted missing width', scope)
local invalid_input_width_ok = pcall(render_buffer.append_input, {}, { inputs = {} }, 'name', 'name', 'value', {
  width = math.huge,
})
h.assert_true(not invalid_input_width_ok, 'input append helper accepted non-finite width', scope)
local invalid_append_lines_ok = pcall(render_buffer.append_input, false, { inputs = {} }, 'name', 'name', 'value', {
  width = 10,
})
h.assert_true(not invalid_append_lines_ok, 'input append helper accepted non-table lines', scope)
local invalid_append_geometry_ok = pcall(render_buffer.append_input, {}, {}, 'name', 'name', 'value', { width = 10 })
h.assert_true(not invalid_append_geometry_ok, 'input append helper accepted geometry without inputs', scope)
local non_sequence_append_geometry_ok = pcall(render_buffer.append_input, {}, {
  inputs = {
    [2] = { name = 'late', kind = 'name', line = 1 },
  },
}, 'name', 'name', 'value', { width = 10 })
h.assert_true(not non_sequence_append_geometry_ok, 'input append helper accepted non-sequence geometry inputs', scope)
local invalid_append_value_ok = pcall(render_buffer.append_input, {}, { inputs = {} }, 'name', 'name', false, {
  width = 10,
})
h.assert_true(not invalid_append_value_ok, 'input append helper accepted non-string value', scope)
local duplicate_append_input_ok = pcall(
  render_buffer.append_input,
  {},
  {
    inputs = {},
    name = {
      line = 1,
    },
  },
  'name',
  'name',
  'value',
  {
    width = 10,
  }
)
h.assert_true(not duplicate_append_input_ok, 'input append helper accepted a duplicate input name', scope)
local invalid_search_instance_ok = pcall(render_buffer.append_search_inputs, nil, {}, render_buffer.new_geometry(), 80)
h.assert_true(not invalid_search_instance_ok, 'search input append accepted missing instance', scope)
local invalid_search_width_ok = pcall(
  render_buffer.append_search_inputs,
  { state = { name_query = '', color_query = '' } },
  {},
  render_buffer.new_geometry(),
  0
)
h.assert_true(not invalid_search_width_ok, 'search input append accepted invalid width', scope)
local invalid_editor_geometry_ok = pcall(render_buffer.absolutize_editor_geometry, {}, 1)
h.assert_true(not invalid_editor_geometry_ok, 'editor geometry absolutizer accepted missing rows', scope)
local invalid_editor_line_ok =
  pcall(render_buffer.absolutize_editor_geometry, { editor_rows = { sample = { line = 0 } } }, 1)
h.assert_true(not invalid_editor_line_ok, 'editor geometry absolutizer accepted invalid row line', scope)
local invalid_detail_geometry_ok = pcall(render_buffer.absolutize_detail_menu_geometry, {}, 1)
h.assert_true(not invalid_detail_geometry_ok, 'detail geometry absolutizer accepted missing rows', scope)
h.with_temp_buf(function(buf)
  local instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-buffer-test'),
    input_ns = vim.api.nvim_create_namespace('hlcraft-ui-render-buffer-input-test'),
    state = {
      buf = buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  render_buffer.set_lines(instance, { 'one', 'two' })
  h.assert_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[2], 'two', 'render buffer did not set lines', scope)
  instance.state.rendering = true
  render_buffer.set_lines(instance, { 'rendering' })
  h.assert_true(instance.state.rendering, 'render buffer set_lines cleared an existing rendering state', scope)
  instance.state.rendering = false
  local geometry = render_buffer.new_geometry()
  render_buffer.finish(instance, geometry)
  h.assert_equal(instance.state.geometry, geometry, 'render buffer did not store geometry', scope)
  h.assert_true(type(instance.state.input_marks) == 'table', 'render buffer did not reset input marks', scope)
  h.assert_true(
    type(instance.state.placeholder_marks) == 'table',
    'render buffer did not reset placeholder marks',
    scope
  )
  local tracked_geometry = render_buffer.new_geometry()
  tracked_geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
  }
  render_buffer.finish(instance, tracked_geometry)
  local previous_geometry = instance.state.geometry
  local previous_extmark_ids = instance.state.extmark_ids
  local previous_input_marks = {
    name = 1,
  }
  local previous_placeholder_marks = {
    color = 2,
  }
  instance.state.input_marks = previous_input_marks
  instance.state.placeholder_marks = previous_placeholder_marks
  local failed_geometry = render_buffer.new_geometry()
  failed_geometry.inputs = {
    { name = 'name', kind = 'name', line = 3 },
  }
  local failed_finish_ok = pcall(render_buffer.finish, instance, failed_geometry)
  h.assert_true(not failed_finish_ok, 'render buffer finish accepted out-of-range input geometry', scope)
  h.assert_equal(instance.state.geometry, previous_geometry, 'failed render finish changed geometry state', scope)
  h.assert_equal(instance.state.extmark_ids, previous_extmark_ids, 'failed render finish changed extmark state', scope)
  h.assert_equal(instance.state.input_marks, previous_input_marks, 'failed render finish changed input marks', scope)
  h.assert_equal(
    instance.state.placeholder_marks,
    previous_placeholder_marks,
    'failed render finish changed placeholder marks',
    scope
  )
  local original_theme_apply = theme.apply
  local failed_theme_geometry = render_buffer.new_geometry()
  failed_theme_geometry.inputs = {
    { name = 'color', kind = 'color', line = 1 },
  }
  theme.apply = function()
    error('theme failed')
  end
  local failed_theme_finish_ok = pcall(render_buffer.finish, instance, failed_theme_geometry)
  theme.apply = original_theme_apply
  h.assert_true(not failed_theme_finish_ok, 'render buffer finish accepted failed theme apply', scope)
  h.assert_equal(instance.state.geometry, previous_geometry, 'theme-failed render finish changed geometry state', scope)
  h.assert_equal(
    instance.state.extmark_ids,
    previous_extmark_ids,
    'theme-failed render finish changed extmark state',
    scope
  )
  local input_ns = instance.input_ns
  local preserved_mark = vim.api.nvim_buf_get_extmark_by_id(buf, input_ns, previous_extmark_ids['name:start'], {})
  h.assert_true(#preserved_mark > 0, 'theme-failed render finish deleted existing input extmark', scope)
  local original_set_extmark = vim.api.nvim_buf_set_extmark
  vim.api.nvim_buf_set_extmark = function()
    error('extmark failed')
  end
  local failed_extmark_geometry = render_buffer.new_geometry()
  failed_extmark_geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
  }
  local failed_extmark_finish_ok = pcall(render_buffer.finish, instance, failed_extmark_geometry)
  vim.api.nvim_buf_set_extmark = original_set_extmark
  h.assert_true(not failed_extmark_finish_ok, 'render buffer finish accepted failed extmark refresh', scope)
  h.assert_equal(
    instance.state.geometry,
    previous_geometry,
    'extmark-failed render finish changed geometry state',
    scope
  )
  h.assert_equal(
    instance.state.extmark_ids,
    previous_extmark_ids,
    'extmark-failed render finish changed extmark state',
    scope
  )
  local extmark_failure_preserved =
    vim.api.nvim_buf_get_extmark_by_id(buf, input_ns, previous_extmark_ids['name:start'], {})
  h.assert_true(#extmark_failure_preserved > 0, 'extmark-failed render finish deleted existing input extmark', scope)
  local original_clear_namespace = vim.api.nvim_buf_clear_namespace
  vim.api.nvim_buf_clear_namespace = function()
    error('clear namespace failed')
  end
  local failed_clear_geometry = render_buffer.new_geometry()
  failed_clear_geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
  }
  local failed_clear_finish_ok = pcall(render_buffer.finish, instance, failed_clear_geometry)
  vim.api.nvim_buf_clear_namespace = original_clear_namespace
  h.assert_true(not failed_clear_finish_ok, 'render buffer finish accepted failed namespace cleanup', scope)
  h.assert_equal(
    instance.state.geometry,
    previous_geometry,
    'namespace-failed render finish changed geometry state',
    scope
  )
  h.assert_equal(
    instance.state.extmark_ids,
    previous_extmark_ids,
    'namespace-failed render finish changed extmark state',
    scope
  )
  local namespace_failure_preserved =
    vim.api.nvim_buf_get_extmark_by_id(buf, input_ns, previous_extmark_ids['name:start'], {})
  h.assert_true(
    #namespace_failure_preserved > 0,
    'namespace-failed render finish deleted existing input extmark',
    scope
  )
  local original_buffer_set_extmarks = buffer_fields.set_extmarks
  local original_transaction_clear_namespace = vim.api.nvim_buf_clear_namespace
  buffer_fields.set_extmarks = function()
    return {
      rollback = function()
        error('input extmark rollback failed')
      end,
    }
  end
  vim.api.nvim_buf_clear_namespace = function()
    error('clear namespace failed')
  end
  local failed_transaction_ok, failed_transaction_err =
    pcall(render_buffer.finish, instance, render_buffer.new_geometry())
  buffer_fields.set_extmarks = original_buffer_set_extmarks
  vim.api.nvim_buf_clear_namespace = original_transaction_clear_namespace
  h.assert_true(not failed_transaction_ok, 'render finish accepted failed extmark rollback', scope)
  h.assert_true(
    tostring(failed_transaction_err):find('input extmark rollback failed', 1, true) ~= nil,
    'render finish did not report extmark rollback failure',
    scope
  )
  local original_buf_set_lines = vim.api.nvim_buf_set_lines
  vim.api.nvim_buf_set_lines = function()
    error('set lines failed')
  end
  local failed_set_lines_ok = pcall(render_buffer.set_lines, instance, { 'next' })
  vim.api.nvim_buf_set_lines = original_buf_set_lines
  h.assert_true(not failed_set_lines_ok, 'render buffer set_lines swallowed buffer write failure', scope)
  h.assert_true(not instance.state.rendering, 'failed render buffer set_lines kept rendering state', scope)
  instance.state.rendering = true
  vim.api.nvim_buf_set_lines = function()
    error('set lines failed')
  end
  local failed_nested_set_lines_ok = pcall(render_buffer.set_lines, instance, { 'next' })
  vim.api.nvim_buf_set_lines = original_buf_set_lines
  h.assert_true(not failed_nested_set_lines_ok, 'nested render buffer set_lines swallowed buffer write failure', scope)
  h.assert_true(instance.state.rendering, 'failed render buffer set_lines cleared an existing rendering state', scope)
  instance.state.rendering = false
  local old_decoration_id = vim.api.nvim_buf_set_extmark(buf, instance.ns, 0, 0, {
    virt_lines = {
      { { 'old header', 'ErrorMsg' } },
    },
    virt_lines_above = true,
    virt_lines_leftcol = true,
    right_gravity = false,
  })
  local replacement_geometry = render_buffer.new_geometry()
  replacement_geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
  }
  local replace_failure_ok = pcall(render_buffer.replace, instance, { 'replacement' }, replacement_geometry, function()
    error('decoration failed')
  end)
  h.assert_true(not replace_failure_ok, 'render buffer replace accepted failed callback', scope)
  local old_decoration = vim.api.nvim_buf_get_extmark_by_id(buf, instance.ns, old_decoration_id, {
    details = true,
  })
  h.assert_true(#old_decoration > 0, 'failed render buffer replace dropped previous namespace decoration', scope)
  h.assert_equal(
    old_decoration[3].virt_lines[1][1][1],
    'old header',
    'failed render buffer replace restored wrong namespace decoration',
    scope
  )
  local invalid_lines_ok = pcall(render_buffer.set_lines, instance, { 'ok', false })
  h.assert_true(not invalid_lines_ok, 'render buffer accepted non-string lines', scope)
  local non_sequence_lines_ok = pcall(render_buffer.set_lines, instance, { [2] = 'late' })
  h.assert_true(not non_sequence_lines_ok, 'render buffer accepted non-sequence lines', scope)
  local invalid_finish_ns_ok = pcall(render_buffer.finish, {
    state = {
      buf = buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }, geometry)
  h.assert_true(not invalid_finish_ns_ok, 'render buffer finish accepted missing namespace', scope)
  local invalid_finish_geometry_ok = pcall(render_buffer.finish, instance, false)
  h.assert_true(not invalid_finish_geometry_ok, 'render buffer finish accepted non-table geometry', scope)
  local invalid_finish_inputs_ok = pcall(render_buffer.finish, instance, {})
  h.assert_true(not invalid_finish_inputs_ok, 'render buffer finish accepted geometry without inputs', scope)
  local non_sequence_finish_inputs_ok = pcall(render_buffer.finish, instance, {
    inputs = {
      [2] = { name = 'late', kind = 'name', line = 1 },
    },
  })
  h.assert_true(not non_sequence_finish_inputs_ok, 'render buffer finish accepted non-sequence geometry inputs', scope)
end)

print('hlcraft ui render buffer: OK')
