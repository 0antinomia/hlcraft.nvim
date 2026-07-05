local h = require('tests.helpers')
local scope = 'hlcraft ui render'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local blend_renderer = require('hlcraft.ui.render.editors.blend')
local color_renderer = require('hlcraft.ui.render.editors.color')
local decorations = require('hlcraft.ui.render.decorations')
local detail_renderer = require('hlcraft.ui.render.detail')
local dynamic_renderer = require('hlcraft.ui.render.editors.dynamic')
local dynamic_model = require('hlcraft.dynamic.model')
local engine = require('hlcraft.engine.service')
local editor_layout = require('hlcraft.ui.render.editor_layout')
local editor_rows = require('hlcraft.ui.render.editor_rows')
local field_editor_renderer = require('hlcraft.ui.render.field_editor')
local group_renderer = require('hlcraft.ui.render.editors.group')
local list_renderer = require('hlcraft.ui.render.list')
local render_buffer = require('hlcraft.ui.render.buffer')
local search_renderer = require('hlcraft.ui.render.search')
local render_util = require('hlcraft.render.util')
local theme = require('hlcraft.ui.theme')
local ui_state = require('hlcraft.ui.state')

local persist_dir = h.temp_dir('hlcraft-ui-render')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

vim.api.nvim_set_hl(0, 'HlcraftUiRenderNormal', {
  fg = '#111111',
  bg = '#222222',
  sp = '#333333',
})
engine.set_group('HlcraftUiRenderNormal', 'ui-render')

local instance = {
  state = {
    dynamic_preview = ui_state.dynamic_preview(),
  },
  rerender = function() end,
}
local result = {
  name = 'HlcraftUiRenderNormal',
  fg = '#111111',
  resolved_fg = '#111111',
  bg = '#222222',
  resolved_bg = '#222222',
  sp = '#333333',
}

local editor_geometry = { editor_rows = {} }
local editor_lines = {}
local editor_row = editor_rows.append(editor_lines, editor_geometry, 'sample_row', 'Sample')
h.assert_equal(editor_row.line, 1, 'editor row helper returned wrong line', scope)
h.assert_equal(editor_row.key, 'sample_row', 'editor row helper returned wrong key', scope)
h.assert_equal(editor_geometry.editor_rows.sample_row, editor_row, 'editor row helper did not register geometry', scope)
h.assert_equal(editor_lines[1], 'Sample', 'editor row helper did not append line', scope)
local invalid_input_extra_ok = pcall(render_buffer.new_input_field, 'name', 'name', 1, false)
h.assert_true(not invalid_input_extra_ok, 'input field helper accepted non-table extra options', scope)
local invalid_input_name_ok = pcall(render_buffer.new_input_field, '', 'name', 1)
h.assert_true(not invalid_input_name_ok, 'input field helper accepted an empty name', scope)
local invalid_input_kind_ok = pcall(render_buffer.new_input_field, 'name', false, 1)
h.assert_true(not invalid_input_kind_ok, 'input field helper accepted a non-string kind', scope)
local invalid_input_line_ok = pcall(render_buffer.new_input_field, 'name', 'name', 0)
h.assert_true(not invalid_input_line_ok, 'input field helper accepted an invalid line', scope)
local invalid_editor_row_lines_ok = pcall(editor_rows.append, false, { editor_rows = {} }, 'sample', 'Sample')
h.assert_true(not invalid_editor_row_lines_ok, 'editor row helper accepted non-table lines', scope)
local non_sequence_editor_row_lines_ok = pcall(
  editor_rows.append,
  { [2] = 'stale' },
  { editor_rows = {} },
  'sample',
  'Sample'
)
h.assert_true(not non_sequence_editor_row_lines_ok, 'editor row helper accepted non-sequence lines', scope)
local invalid_editor_row_geometry_ok = pcall(editor_rows.append, {}, {}, 'sample', 'Sample')
h.assert_true(not invalid_editor_row_geometry_ok, 'editor row helper accepted missing row geometry', scope)
local invalid_editor_row_key_ok = pcall(editor_rows.append, {}, { editor_rows = {} }, '', 'Sample')
h.assert_true(not invalid_editor_row_key_ok, 'editor row helper accepted empty key', scope)
local invalid_editor_row_text_ok = pcall(editor_rows.append, {}, { editor_rows = {} }, 'sample', '')
h.assert_true(not invalid_editor_row_text_ok, 'editor row helper accepted empty text', scope)
local duplicate_editor_row_ok = pcall(editor_rows.append, {}, {
  editor_rows = {
    sample = {
      line = 1,
    },
  },
}, 'sample', 'Sample')
h.assert_true(not duplicate_editor_row_ok, 'editor row helper accepted a duplicate key', scope)
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
  local render_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-buffer-test'),
    state = {
      buf = buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  render_buffer.set_lines(render_instance, { 'one', 'two' })
  h.assert_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[2], 'two', 'render buffer did not set lines', scope)
  local geometry = render_buffer.new_geometry()
  render_buffer.finish(render_instance, geometry)
  h.assert_equal(render_instance.state.geometry, geometry, 'render buffer did not store geometry', scope)
  h.assert_true(type(render_instance.state.input_marks) == 'table', 'render buffer did not reset input marks', scope)
  h.assert_true(
    type(render_instance.state.placeholder_marks) == 'table',
    'render buffer did not reset placeholder marks',
    scope
  )
  local invalid_lines_ok = pcall(render_buffer.set_lines, render_instance, { 'ok', false })
  h.assert_true(not invalid_lines_ok, 'render buffer accepted non-string lines', scope)
  local non_sequence_lines_ok = pcall(render_buffer.set_lines, render_instance, { [2] = 'late' })
  h.assert_true(not non_sequence_lines_ok, 'render buffer accepted non-sequence lines', scope)
  local invalid_finish_ns_ok = pcall(render_buffer.finish, {
    state = {
      buf = buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }, geometry)
  h.assert_true(not invalid_finish_ns_ok, 'render buffer finish accepted missing namespace', scope)
  local invalid_finish_geometry_ok = pcall(render_buffer.finish, render_instance, false)
  h.assert_true(not invalid_finish_geometry_ok, 'render buffer finish accepted non-table geometry', scope)
  local invalid_finish_inputs_ok = pcall(render_buffer.finish, render_instance, {})
  h.assert_true(not invalid_finish_inputs_ok, 'render buffer finish accepted geometry without inputs', scope)
  local non_sequence_finish_inputs_ok = pcall(render_buffer.finish, render_instance, {
    inputs = {
      [2] = { name = 'late', kind = 'name', line = 1 },
    },
  })
  h.assert_true(not non_sequence_finish_inputs_ok, 'render buffer finish accepted non-sequence geometry inputs', scope)
end)
local list_lines, list_selectable = list_renderer.build({ state = { results = { result } } }, 80)
h.assert_true(#list_lines >= 3, 'result list renderer did not produce rows', scope)
h.assert_equal(list_selectable[3], 1, 'result list renderer did not register selectable row', scope)
local empty_list_lines = list_renderer.build({ state = { results = {}, name_query = '', color_query = '' } }, 80)
h.assert_equal(
  empty_list_lines[3],
  'Use Name and Color search together to narrow highlight groups',
  'result list renderer lost empty message',
  scope
)
local invalid_list_instance_ok = pcall(list_renderer.build, nil, 80)
h.assert_true(not invalid_list_instance_ok, 'result list renderer accepted missing instance', scope)
local invalid_list_results_ok = pcall(list_renderer.build, { state = {} }, 80)
h.assert_true(not invalid_list_results_ok, 'result list renderer accepted missing results', scope)
local sparse_list_results_ok = pcall(list_renderer.build, { state = { results = { [2] = result } } }, 80)
h.assert_true(not sparse_list_results_ok, 'result list renderer accepted sparse results', scope)
local invalid_list_width_ok = pcall(list_renderer.build, { state = { results = {} } }, math.huge)
h.assert_true(not invalid_list_width_ok, 'result list renderer accepted non-finite width', scope)
local invalid_list_result_ok = pcall(list_renderer.build, { state = { results = { {} } } }, 80)
h.assert_true(not invalid_list_result_ok, 'result list renderer accepted nameless result', scope)
local invalid_list_color_ok =
  pcall(list_renderer.build, { state = { results = { { name = 'Normal', fg = false } } } }, 80)
h.assert_true(not invalid_list_color_ok, 'result list renderer accepted non-string color', scope)
h.with_temp_buf(function(buf)
  local search_instance = {
    id = 'ui-render-search-test',
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-search-test'),
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      name_query = '',
      color_query = '',
      results = { result },
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  search_renderer.render(search_instance)
  h.assert_equal(
    search_instance.state.geometry.result_lines[7],
    1,
    'search renderer did not register result row',
    scope
  )
  local rendered = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  h.assert_true(rendered:find(result.name, 1, true) ~= nil, 'search renderer did not render result name', scope)

  local missing_search_instance_ok = pcall(search_renderer.render, nil)
  h.assert_true(not missing_search_instance_ok, 'search renderer accepted missing instance', scope)
  local missing_search_results_ok = pcall(search_renderer.render, {
    id = 'ui-render-search-missing-results-test',
    ns = search_instance.ns,
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      name_query = '',
      color_query = '',
      dynamic_preview = ui_state.dynamic_preview(),
    },
  })
  h.assert_true(not missing_search_results_ok, 'search renderer accepted missing results', scope)
  local sparse_search_results_ok = pcall(search_renderer.render, {
    id = 'ui-render-search-sparse-results-test',
    ns = search_instance.ns,
    input_label_hl = theme.groups.label,
    state = {
      results = {
        [2] = result,
      },
    },
  })
  h.assert_true(not sparse_search_results_ok, 'search renderer accepted sparse results', scope)
  local missing_search_namespace_ok = pcall(search_renderer.render, {
    id = 'ui-render-search-missing-namespace-test',
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      name_query = '',
      color_query = '',
      results = { result },
      dynamic_preview = ui_state.dynamic_preview(),
    },
  })
  h.assert_true(not missing_search_namespace_ok, 'search renderer accepted missing namespace', scope)
  local invalid_search_color_ok = pcall(search_renderer.render, {
    id = 'ui-render-search-invalid-color-test',
    ns = search_instance.ns,
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      name_query = '',
      color_query = '',
      results = {
        {
          name = 'InvalidColorResult',
          fg = false,
        },
      },
      dynamic_preview = ui_state.dynamic_preview(),
    },
  })
  h.assert_true(not invalid_search_color_ok, 'search renderer accepted invalid result color', scope)
end, { current = true })
h.assert_equal(render_util.truncate('abcdef', 4), 'abc…', 'render truncate lost ellipsis budget', scope)
h.assert_equal(
  render_util.truncate('你好世界', 5),
  '你好…',
  'render truncate split wide text incorrectly',
  scope
)
h.assert_equal(render_util.truncate('abcdef', 0), '', 'render truncate ignored zero width', scope)
h.assert_equal(render_util.pad('abc', 5), 'abc  ', 'render pad did not append display padding', scope)
h.assert_equal(render_util.line_at({ 'first' }, 1, 'test geometry'), 'first', 'render line lookup changed', scope)
h.assert_equal(render_util.line_offset(3, 'test geometry'), 3, 'render line offset lookup changed', scope)
local strict_truncate_text_ok = pcall(render_util.truncate, nil, 4)
h.assert_true(not strict_truncate_text_ok, 'render truncate accepted nil text', scope)
local strict_truncate_width_ok = pcall(render_util.truncate, 'abc', math.huge)
h.assert_true(not strict_truncate_width_ok, 'render truncate accepted non-finite width', scope)
local strict_string_list_ok = pcall(render_util.string_list, { [2] = 'late' }, 'test lines')
h.assert_true(not strict_string_list_ok, 'render string list accepted non-sequence lines', scope)
local strict_pad_text_ok = pcall(render_util.pad, 1, 4)
h.assert_true(not strict_pad_text_ok, 'render pad accepted non-string text', scope)
local strict_pad_width_ok = pcall(render_util.pad, 'abc', 1.5)
h.assert_true(not strict_pad_width_ok, 'render pad accepted fractional width', scope)
local missing_render_line_ok = pcall(render_util.line_at, { 'first' }, 2, 'test geometry')
h.assert_true(not missing_render_line_ok, 'render line lookup accepted missing line', scope)
local invalid_render_line_nr_ok = pcall(render_util.line_at, { 'first' }, 0, 'test geometry')
h.assert_true(not invalid_render_line_nr_ok, 'render line lookup accepted invalid line number', scope)
local invalid_render_offset_ok = pcall(render_util.line_offset, -1, 'test geometry')
h.assert_true(not invalid_render_offset_ok, 'render line offset accepted a negative value', scope)
local layout_lines = editor_layout.finish({ 'Current: abcdefghijklmnop' }, 12, { 'Action  [x] go' })
h.assert_equal(layout_lines[2], '', 'editor layout did not separate hints from content', scope)
h.assert_true(vim.fn.strdisplaywidth(layout_lines[1]) <= 12, 'editor layout did not truncate content lines', scope)
h.assert_true(vim.fn.strdisplaywidth(layout_lines[3]) <= 12, 'editor layout did not truncate hint lines', scope)
local invalid_layout_lines_ok = pcall(editor_layout.finish, false, 12, {})
h.assert_true(not invalid_layout_lines_ok, 'editor layout accepted non-table lines', scope)
local invalid_layout_width_ok = pcall(editor_layout.finish, {}, math.huge, {})
h.assert_true(not invalid_layout_width_ok, 'editor layout accepted non-finite width', scope)
local invalid_layout_hints_ok = pcall(editor_layout.finish, {}, 12, { false })
h.assert_true(not invalid_layout_hints_ok, 'editor layout accepted non-string hint line', scope)
local nil_find_line_ok = pcall(decorations.find_text_start, nil, 'x', 0)
h.assert_true(not nil_find_line_ok, 'text finder accepted nil line', scope)
local nil_find_text_ok = pcall(decorations.find_text_start, 'x', nil, 0)
h.assert_true(not nil_find_text_ok, 'text finder accepted nil text', scope)
local invalid_find_start_ok = pcall(decorations.find_text_start, 'x', 'x', 0.5)
h.assert_true(not invalid_find_start_ok, 'text finder accepted fractional start column', scope)
local required_text_col = decorations.require_text_start('left right', 'right', 0, 'test marker')
h.assert_equal(required_text_col, 5, 'required text finder returned the wrong column', scope)
local missing_required_text_ok = pcall(decorations.require_text_start, 'left right', 'missing', 0, 'test marker')
h.assert_true(not missing_required_text_ok, 'required text finder accepted missing text', scope)
local invalid_required_label_ok = pcall(decorations.require_text_start, 'left right', 'left', 0, '')
h.assert_true(not invalid_required_label_ok, 'required text finder accepted an empty label', scope)
local invalid_header_opts_ok = pcall(decorations.set_input_header, {}, {}, 'Label', false)
h.assert_true(not invalid_header_opts_ok, 'input header accepted non-table options', scope)
h.with_temp_buf(function(buf)
  local decoration_instance = {
    id = 'ui-render-decoration-test',
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-decoration-test'),
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      input_marks = {},
    },
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'Name', 'Result' })
  decorations.set_input_header(decoration_instance, { line = 1 }, 'Name', {
    extra = 'query',
    top_virt_lines = { decorations.help_virt_line() },
  })
  decorations.set_results_header(decoration_instance, 2, 80)
  decorations.apply_color_cell(decoration_instance, buf, 0, 0, 'Name', '#ffffff', 'fg')
  local color_hl = decorations.detail_color_hl(decoration_instance, '#ffffff', 'fg')
  h.assert_true(type(color_hl) == 'string' and color_hl ~= '', 'detail color highlight was not created', scope)
  h.assert_true(next(decoration_instance.state.input_marks) ~= nil, 'input header marks were not stored', scope)

  local missing_decoration_instance_ok = pcall(decorations.set_results_header, nil, 1, 80)
  h.assert_true(not missing_decoration_instance_ok, 'decorations accepted missing instance', scope)
  local invalid_header_line_ok = pcall(decorations.set_input_header, decoration_instance, { line = 0 }, 'Name')
  h.assert_true(not invalid_header_line_ok, 'input header accepted invalid field line', scope)
  local invalid_header_extra_ok = pcall(decorations.set_input_header, decoration_instance, { line = 1 }, 'Name', {
    extra = false,
  })
  h.assert_true(not invalid_header_extra_ok, 'input header accepted non-string extra text', scope)
  local invalid_header_virt_ok = pcall(decorations.set_input_header, decoration_instance, { line = 1 }, 'Name', {
    top_virt_lines = { false },
  })
  h.assert_true(not invalid_header_virt_ok, 'input header accepted invalid virtual lines', scope)
  local sparse_header_virt_lines_ok = pcall(decorations.set_input_header, decoration_instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      [2] = decorations.help_virt_line(),
    },
  })
  h.assert_true(not sparse_header_virt_lines_ok, 'input header accepted sparse virtual lines', scope)
  local sparse_header_virt_line_ok = pcall(decorations.set_input_header, decoration_instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      {
        [2] = { '?', theme.groups.key },
      },
    },
  })
  h.assert_true(not sparse_header_virt_line_ok, 'input header accepted sparse virtual line chunks', scope)
  local keyed_header_virt_chunk_ok = pcall(decorations.set_input_header, decoration_instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      {
        { text = '?', hl = theme.groups.key },
      },
    },
  })
  h.assert_true(not keyed_header_virt_chunk_ok, 'input header accepted keyed virtual line chunk', scope)
  local invalid_results_width_ok = pcall(decorations.set_results_header, decoration_instance, 1, 0)
  h.assert_true(not invalid_results_width_ok, 'results header accepted invalid width', scope)
  local invalid_color_buf_ok = pcall(decorations.apply_color_cell, decoration_instance, -1, 0, 0, 'x', '#ffffff', 'fg')
  h.assert_true(not invalid_color_buf_ok, 'color cell accepted invalid buffer', scope)
  local invalid_color_suffix_ok =
    pcall(decorations.apply_color_cell, decoration_instance, buf, 0, 0, 'x', '#ffffff', '')
  h.assert_true(not invalid_color_suffix_ok, 'color cell accepted empty suffix', scope)
  local invalid_detail_color_bg_ok = pcall(decorations.detail_color_hl, decoration_instance, false, 'fg')
  h.assert_true(not invalid_detail_color_bg_ok, 'detail color highlight accepted invalid background', scope)
end)

local strict_detail_ok = pcall(detail_renderer.build, { detail_menu = {} }, result, 80)
h.assert_true(not strict_detail_ok, 'detail renderer accepted a build call without instance', scope)
local strict_detail_geometry_ok = pcall(detail_renderer.build, instance, {}, result, 80)
h.assert_true(not strict_detail_geometry_ok, 'detail renderer accepted missing detail geometry', scope)
local strict_detail_result_ok = pcall(detail_renderer.build, instance, { detail_menu = {} }, {}, 80)
h.assert_true(not strict_detail_result_ok, 'detail renderer accepted missing highlight result', scope)
local strict_detail_offset_ok = pcall(detail_renderer.build, instance, { detail_menu = {} }, result, 80)
h.assert_true(not strict_detail_offset_ok, 'detail renderer accepted missing line offset', scope)
local strict_field_editor_ok = pcall(field_editor_renderer.build, { editor_rows = {} }, result, 'fg', 80)
h.assert_true(not strict_field_editor_ok, 'field editor renderer accepted a build call without instance', scope)
local strict_field_editor_geometry_ok = pcall(field_editor_renderer.build, instance, {}, result, 'fg', 80)
h.assert_true(not strict_field_editor_geometry_ok, 'field editor renderer accepted missing editor geometry', scope)
local strict_field_editor_result_ok = pcall(field_editor_renderer.build, instance, { editor_rows = {} }, {}, 'fg', 80)
h.assert_true(not strict_field_editor_result_ok, 'field editor renderer accepted missing highlight result', scope)
local strict_field_editor_result_name_ok = pcall(
  field_editor_renderer.build,
  instance,
  { editor_rows = {} },
  { name = '' },
  'fg',
  80,
  0
)
h.assert_true(not strict_field_editor_result_name_ok, 'field editor renderer accepted empty result name', scope)
local strict_field_editor_field_ok = pcall(field_editor_renderer.build, instance, { editor_rows = {} }, result, nil, 80)
h.assert_true(not strict_field_editor_field_ok, 'field editor renderer accepted missing field', scope)
local strict_field_editor_empty_field_ok =
  pcall(field_editor_renderer.build, instance, { editor_rows = {} }, result, '', 80, 0)
h.assert_true(not strict_field_editor_empty_field_ok, 'field editor renderer accepted empty field', scope)
local strict_field_editor_offset_ok =
  pcall(field_editor_renderer.build, instance, { editor_rows = {} }, result, 'fg', 80)
h.assert_true(not strict_field_editor_offset_ok, 'field editor renderer accepted missing line offset', scope)
local strict_field_editor_render_state_ok = pcall(field_editor_renderer.render, { state = {} })
h.assert_true(
  not strict_field_editor_render_state_ok,
  'field editor renderer accepted missing field editor state',
  scope
)
local strict_field_editor_render_field_ok = pcall(field_editor_renderer.render, {
  state = {
    field_editor = { field = false },
  },
})
h.assert_true(not strict_field_editor_render_field_ok, 'field editor renderer accepted invalid current field', scope)

local detail_geometry = { detail_menu = {} }
local detail_lines = detail_renderer.build(instance, detail_geometry, result, 80, 0)
local fg_row = detail_geometry.detail_menu.fg
h.assert_true(fg_row.label_start_col ~= nil, 'detail row lacks label highlight start', scope)
h.assert_true(fg_row.label_end_col > fg_row.label_start_col, 'detail row label highlight range is invalid', scope)
h.assert_true(fg_row.value_col > fg_row.label_end_col, 'detail row lacks value highlight start', scope)
h.with_temp_buf(function(buf)
  local detail_ns = vim.api.nvim_create_namespace('hlcraft-ui-render-detail-test')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, detail_lines)
  decorations.apply_detail_menu_highlights({
    ns = detail_ns,
    state = {
      buf = buf,
    },
  }, detail_geometry.detail_menu, false)
  local marks = vim.api.nvim_buf_get_extmarks(buf, detail_ns, 0, -1, { details = true })
  h.assert_true(#marks > 0, 'detail menu highlights were not applied', scope)
end)
h.with_temp_buf(function(buf)
  local invalid_detail_menu_ok = pcall(decorations.apply_detail_menu_highlights, {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-invalid-detail-menu-test'),
    state = {
      buf = buf,
    },
  }, nil, false)
  h.assert_true(not invalid_detail_menu_ok, 'detail menu highlighter accepted nil geometry', scope)
  local invalid_dirty_flag_ok = pcall(decorations.apply_detail_menu_highlights, {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-invalid-dirty-test'),
    state = {
      buf = buf,
    },
  }, {}, 'dirty')
  h.assert_true(not invalid_dirty_flag_ok, 'detail menu highlighter accepted non-boolean dirty flag', scope)
  local invalid_detail_row_ok = pcall(decorations.apply_detail_menu_highlights, {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-invalid-detail-row-test'),
    state = {
      buf = buf,
    },
  }, {
    fg = { line = 0 },
  }, false)
  h.assert_true(not invalid_detail_row_ok, 'detail menu highlighter accepted invalid row geometry', scope)
end)

local top_help = ''
for _, chunk in ipairs(decorations.help_virt_line()) do
  top_help = top_help .. chunk[1]
end
h.assert_true(top_help:find('? help', 1, true) ~= nil, 'top help line should keep help discovery', scope)
h.assert_true(top_help:find('Enter', 1, true) == nil, 'top help line should not repeat scene actions', scope)
h.assert_true(top_help:find('Tab', 1, true) == nil, 'top help line should not repeat input navigation', scope)

local ns = vim.api.nvim_create_namespace('hlcraft-ui-render-test')
local non_numeric_theme_ns_ok = pcall(theme.apply, false)
h.assert_true(not non_numeric_theme_ns_ok, 'theme accepted non-numeric namespace', scope)
local infinite_theme_ns_ok = pcall(theme.apply, math.huge)
h.assert_true(not infinite_theme_ns_ok, 'theme accepted infinite namespace', scope)
theme.apply(ns)
for _, group_name in ipairs({
  theme.groups.section,
  theme.groups.hint,
  theme.groups.hint_action,
  theme.groups.value,
  theme.groups.key,
  theme.groups.title,
}) do
  h.assert_true(type(group_name) == 'string' and group_name ~= '', 'missing visual hierarchy group', scope)
  local applied = vim.api.nvim_get_hl(ns, { name = group_name })
  h.assert_true(applied.fg ~= nil, ('theme group %s has no foreground'):format(group_name), scope)
end
local hint_hl = vim.api.nvim_get_hl(ns, { name = theme.groups.hint })
local action_hl = vim.api.nvim_get_hl(ns, { name = theme.groups.hint_action })
h.assert_true(action_hl.fg ~= hint_hl.fg, 'hint actions should contrast with muted hint text', scope)

local color_geometry = { editor_rows = {} }
local color_lines = color_renderer.build(color_geometry, result, 'fg', 80)
local color_text = table.concat(color_lines, '\n')
h.assert_true(color_text:find('Adjust  ', 1, true) ~= nil, 'color editor lacks an action section', scope)
h.assert_true(color_text:find('        [b/B] blue', 1, true) ~= nil, 'color editor adjust hints stayed crowded', scope)
h.assert_true(color_text:find('Set     ', 1, true) ~= nil, 'color editor lacks a set section', scope)
h.assert_true(color_text:find('        [d] dynamic', 1, true) ~= nil, 'color editor set hints stayed crowded', scope)
h.assert_true(color_text:find('Global  ', 1, true) ~= nil, 'color editor lacks a global section', scope)
h.assert_true(color_text:find('        [?] help', 1, true) ~= nil, 'color editor global hints stayed crowded', scope)
h.assert_true(not color_text:find('Keys:', 1, true), 'color editor kept crowded Keys hint', scope)
h.assert_true(color_geometry.editor_rows.color_keys == nil, 'color hint row should not be selectable', scope)
local invalid_color_geometry_ok = pcall(color_renderer.build, {}, result, 'fg', 80)
h.assert_true(not invalid_color_geometry_ok, 'color editor accepted missing geometry', scope)
local invalid_color_result_ok = pcall(color_renderer.build, { editor_rows = {} }, {}, 'fg', 80)
h.assert_true(not invalid_color_result_ok, 'color editor accepted missing result', scope)
local invalid_color_field_ok = pcall(color_renderer.build, { editor_rows = {} }, result, '', 80)
h.assert_true(not invalid_color_field_ok, 'color editor accepted empty field', scope)
local invalid_color_width_ok = pcall(color_renderer.build, { editor_rows = {} }, result, 'fg', 0)
h.assert_true(not invalid_color_width_ok, 'color editor accepted invalid width', scope)
local invalid_blend_width_ok = pcall(blend_renderer.build, { editor_rows = {} }, result, 0)
h.assert_true(not invalid_blend_width_ok, 'blend editor accepted invalid width', scope)
local invalid_group_result_ok = pcall(group_renderer.build, { editor_rows = {} }, {}, 80)
h.assert_true(not invalid_group_result_ok, 'group editor accepted missing result', scope)

local dynamic_geometry = { editor_rows = {} }
local dynamic = dynamic_model.normalize_channel({
  version = 1,
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
  },
})
local dynamic_lines = dynamic_renderer.build(instance, dynamic_geometry, result, 'fg', 80, 0, dynamic)
local dynamic_text = table.concat(dynamic_lines, '\n')
h.assert_true(dynamic_geometry.editor_rows.dynamic_loop ~= nil, 'dynamic loop row must stay editable', scope)
h.assert_true(dynamic_geometry.editor_rows.dynamic_phase ~= nil, 'dynamic phase row must stay editable', scope)
h.assert_true(dynamic_text:find('Edit    ', 1, true) ~= nil, 'dynamic editor lacks an edit section', scope)
h.assert_true(dynamic_text:find('Global  ', 1, true) ~= nil, 'dynamic editor lacks a global section', scope)
h.assert_true(not dynamic_text:find('Keys:', 1, true), 'dynamic editor kept crowded Keys hint', scope)
h.assert_true(dynamic_geometry.editor_rows.dynamic_keys == nil, 'dynamic hint row should not be selectable', scope)
local invalid_dynamic_instance_ok =
  pcall(dynamic_renderer.build, nil, { editor_rows = {} }, result, 'fg', 80, 0, dynamic)
h.assert_true(not invalid_dynamic_instance_ok, 'dynamic editor accepted missing instance', scope)
local invalid_dynamic_value_ok =
  pcall(dynamic_renderer.build, instance, { editor_rows = {} }, result, 'fg', 80, 0, false)
h.assert_true(not invalid_dynamic_value_ok, 'dynamic editor accepted invalid dynamic value', scope)

local dynamic_set_ok, dynamic_set_err = engine.set_dynamic('HlcraftUiRenderNormal', 'fg', dynamic)
h.assert_true(dynamic_set_ok, dynamic_set_err or 'dynamic fixture did not set', scope)
local dynamic_detail_geometry = { detail_menu = {} }
local dynamic_detail_lines = detail_renderer.build(instance, dynamic_detail_geometry, result, 80, 0)
local dynamic_detail_text = table.concat(dynamic_detail_lines, '\n')
h.assert_true(
  dynamic_detail_text:find('custom 1000ms repeat', 1, true) ~= nil,
  'detail dynamic metadata did not use normalized values',
  scope
)

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui render: OK')
