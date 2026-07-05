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
local field_editor_renderer = require('hlcraft.ui.render.field_editor')
local group_renderer = require('hlcraft.ui.render.editors.group')
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
  local invalid_header_opts_ok = pcall(decorations.set_input_header, decoration_instance, { line = 1 }, 'Name', false)
  h.assert_true(not invalid_header_opts_ok, 'input header accepted non-table options', scope)
  local unknown_header_opts_ok = pcall(decorations.set_input_header, decoration_instance, { line = 1 }, 'Name', {
    width = 10,
  })
  h.assert_true(not unknown_header_opts_ok, 'input header accepted unknown options', scope)
  local invalid_header_line_ok = pcall(decorations.set_input_header, decoration_instance, { line = 0 }, 'Name')
  h.assert_true(not invalid_header_line_ok, 'input header accepted invalid field line', scope)
  decoration_instance.state.input_marks['Name:1'] = false
  local invalid_header_mark_ok = pcall(decorations.set_input_header, decoration_instance, { line = 1 }, 'Name')
  h.assert_true(not invalid_header_mark_ok, 'input header accepted invalid extmark id', scope)
  decoration_instance.state.input_marks['Name:1'] = nil
  decoration_instance.state.input_marks.results_header = false
  local invalid_results_mark_ok = pcall(decorations.set_results_header, decoration_instance, 2, 80)
  h.assert_true(not invalid_results_mark_ok, 'results header accepted invalid extmark id', scope)
  decoration_instance.state.input_marks.results_header = nil
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
  local invalid_header_virt_chunk_text_ok = pcall(
    decorations.set_input_header,
    decoration_instance,
    { line = 1 },
    'Name',
    {
      top_virt_lines = {
        {
          { false, theme.groups.key },
        },
      },
    }
  )
  h.assert_true(
    not invalid_header_virt_chunk_text_ok,
    'input header accepted non-string virtual line chunk text',
    scope
  )
  local invalid_header_virt_chunk_hl_ok = pcall(
    decorations.set_input_header,
    decoration_instance,
    { line = 1 },
    'Name',
    {
      top_virt_lines = {
        {
          { '?', false },
        },
      },
    }
  )
  h.assert_true(
    not invalid_header_virt_chunk_hl_ok,
    'input header accepted non-string virtual line chunk highlight',
    scope
  )
  local extra_header_virt_chunk_ok = pcall(decorations.set_input_header, decoration_instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      {
        { '?', theme.groups.key, 'extra' },
      },
    },
  })
  h.assert_true(not extra_header_virt_chunk_ok, 'input header accepted oversized virtual line chunk', scope)
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
local strict_detail_empty_result_ok, strict_detail_empty_result_err = pcall(
  detail_renderer.build,
  instance,
  { detail_menu = {} },
  { name = '' },
  80,
  0
)
h.assert_true(not strict_detail_empty_result_ok, 'detail renderer accepted empty highlight result name', scope)
h.assert_true(
  tostring(strict_detail_empty_result_err):find('detail renderer requires a highlight result', 1, true) ~= nil,
  'empty detail result bypassed renderer validation',
  scope
)
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
local narrow_detail_lines = detail_renderer.build(instance, { detail_menu = {} }, result, 30, 0)
h.assert_true(
  vim.tbl_contains(narrow_detail_lines, '        [s] save  [?] help'),
  'detail renderer did not wrap narrow hints',
  scope
)
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
h.assert_true(dynamic_text:find('Sample 0.50:', 1, true) ~= nil, 'dynamic editor omitted timeline samples', scope)
h.assert_true(not dynamic_text:find('Keys:', 1, true), 'dynamic editor kept crowded Keys hint', scope)
h.assert_true(dynamic_geometry.editor_rows.dynamic_keys == nil, 'dynamic hint row should not be selectable', scope)
h.assert_true(
  dynamic_geometry.editor_rows['dynamic_sample:0.50'] == nil,
  'dynamic sample row should not be selectable',
  scope
)
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
h.with_temp_buf(function(buf)
  local dynamic_detail_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-dynamic-detail-test'),
    state = {
      buf = buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  detail_renderer.build(dynamic_detail_instance, { detail_menu = {} }, result, 80, 0)
  h.assert_equal(
    dynamic_detail_instance.state.dynamic_preview.items[1].context.bg,
    '#222222',
    'detail dynamic preview missed renderer color context',
    scope
  )
end)

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui render: OK')
