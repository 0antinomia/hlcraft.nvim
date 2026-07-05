local h = require('tests.helpers')
local scope = 'hlcraft ui render buffer'

local render_buffer = require('hlcraft.ui.render.buffer')
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
    state = {
      buf = buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  render_buffer.set_lines(instance, { 'one', 'two' })
  h.assert_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[2], 'two', 'render buffer did not set lines', scope)
  local geometry = render_buffer.new_geometry()
  render_buffer.finish(instance, geometry)
  h.assert_equal(instance.state.geometry, geometry, 'render buffer did not store geometry', scope)
  h.assert_true(type(instance.state.input_marks) == 'table', 'render buffer did not reset input marks', scope)
  h.assert_true(
    type(instance.state.placeholder_marks) == 'table',
    'render buffer did not reset placeholder marks',
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
