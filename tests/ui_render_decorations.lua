local h = require('tests.helpers')
local scope = 'hlcraft ui render decorations'

local decorations = require('hlcraft.ui.render.decorations')
local theme = require('hlcraft.ui.theme')

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
  local instance = {
    id = 'ui-render-decoration-test',
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-decoration-test'),
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      input_marks = {},
    },
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'Name', 'Result' })
  decorations.set_input_header(instance, { line = 1 }, 'Name', {
    extra = 'query',
    top_virt_lines = { decorations.help_virt_line() },
  })
  decorations.set_results_header(instance, 2, 80)
  decorations.apply_color_cell(instance, buf, 0, 0, 'Name', '#ffffff', 'fg')
  local color_hl = decorations.detail_color_hl(instance, '#ffffff', 'fg')
  h.assert_true(type(color_hl) == 'string' and color_hl ~= '', 'detail color highlight was not created', scope)
  h.assert_true(next(instance.state.input_marks) ~= nil, 'input header marks were not stored', scope)

  local missing_instance_ok = pcall(decorations.set_results_header, nil, 1, 80)
  h.assert_true(not missing_instance_ok, 'decorations accepted missing instance', scope)
  local invalid_header_opts_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', false)
  h.assert_true(not invalid_header_opts_ok, 'input header accepted non-table options', scope)
  local unknown_header_opts_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', {
    width = 10,
  })
  h.assert_true(not unknown_header_opts_ok, 'input header accepted unknown options', scope)
  local invalid_header_line_ok = pcall(decorations.set_input_header, instance, { line = 0 }, 'Name')
  h.assert_true(not invalid_header_line_ok, 'input header accepted invalid field line', scope)
  instance.state.input_marks['Name:1'] = false
  local invalid_header_mark_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name')
  h.assert_true(not invalid_header_mark_ok, 'input header accepted invalid extmark id', scope)
  instance.state.input_marks['Name:1'] = nil
  instance.state.input_marks.results_header = false
  local invalid_results_mark_ok = pcall(decorations.set_results_header, instance, 2, 80)
  h.assert_true(not invalid_results_mark_ok, 'results header accepted invalid extmark id', scope)
  instance.state.input_marks.results_header = nil
  local invalid_header_extra_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', {
    extra = false,
  })
  h.assert_true(not invalid_header_extra_ok, 'input header accepted non-string extra text', scope)
  local invalid_header_virt_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', {
    top_virt_lines = { false },
  })
  h.assert_true(not invalid_header_virt_ok, 'input header accepted invalid virtual lines', scope)
  local sparse_header_virt_lines_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      [2] = decorations.help_virt_line(),
    },
  })
  h.assert_true(not sparse_header_virt_lines_ok, 'input header accepted sparse virtual lines', scope)
  local sparse_header_virt_line_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      {
        [2] = { '?', theme.groups.key },
      },
    },
  })
  h.assert_true(not sparse_header_virt_line_ok, 'input header accepted sparse virtual line chunks', scope)
  local keyed_header_virt_chunk_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      {
        { text = '?', hl = theme.groups.key },
      },
    },
  })
  h.assert_true(not keyed_header_virt_chunk_ok, 'input header accepted keyed virtual line chunk', scope)
  local invalid_header_virt_chunk_text_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      {
        { false, theme.groups.key },
      },
    },
  })
  h.assert_true(
    not invalid_header_virt_chunk_text_ok,
    'input header accepted non-string virtual line chunk text',
    scope
  )
  local invalid_header_virt_chunk_hl_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      {
        { '?', false },
      },
    },
  })
  h.assert_true(
    not invalid_header_virt_chunk_hl_ok,
    'input header accepted non-string virtual line chunk highlight',
    scope
  )
  local extra_header_virt_chunk_ok = pcall(decorations.set_input_header, instance, { line = 1 }, 'Name', {
    top_virt_lines = {
      {
        { '?', theme.groups.key, 'extra' },
      },
    },
  })
  h.assert_true(not extra_header_virt_chunk_ok, 'input header accepted oversized virtual line chunk', scope)
  local invalid_results_width_ok = pcall(decorations.set_results_header, instance, 1, 0)
  h.assert_true(not invalid_results_width_ok, 'results header accepted invalid width', scope)
  local invalid_color_buf_ok = pcall(decorations.apply_color_cell, instance, -1, 0, 0, 'x', '#ffffff', 'fg')
  h.assert_true(not invalid_color_buf_ok, 'color cell accepted invalid buffer', scope)
  local invalid_color_suffix_ok = pcall(decorations.apply_color_cell, instance, buf, 0, 0, 'x', '#ffffff', '')
  h.assert_true(not invalid_color_suffix_ok, 'color cell accepted empty suffix', scope)
  local invalid_detail_color_bg_ok = pcall(decorations.detail_color_hl, instance, false, 'fg')
  h.assert_true(not invalid_detail_color_bg_ok, 'detail color highlight accepted invalid background', scope)
end)

h.with_temp_buf(function(buf)
  local ns = vim.api.nvim_create_namespace('hlcraft-ui-render-detail-menu-test')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '* FG  #ffffff' })
  decorations.apply_detail_menu_highlights({
    ns = ns,
    state = {
      buf = buf,
    },
  }, {
    fg = {
      line = 1,
      label_start_col = 2,
      label_end_col = 4,
      value_col = 6,
    },
  }, true)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
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

print('hlcraft ui render decorations: OK')
