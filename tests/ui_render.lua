local h = require('tests.helpers')
local scope = 'hlcraft ui render'

local config = require('hlcraft.config')
local hlcraft = require('hlcraft')
local detail_renderer = require('hlcraft.ui.render.detail')
local dynamic_model = require('hlcraft.dynamic.model')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local engine = require('hlcraft.engine.service')
local field_editor_renderer = require('hlcraft.ui.render.field_editor')
local ui_state = require('hlcraft.ui.state')

local function assert_preview_range(lines, item, message)
  local line = lines[item.line]
  local start_byte, end_byte = line:find(item.text, 1, true)
  h.assert_true(start_byte ~= nil, message .. ' swatch was not rendered', scope)
  h.assert_equal(item.col_start, start_byte - 1, message .. ' start column changed', scope)
  h.assert_equal(item.col_end, end_byte, message .. ' end column changed', scope)
end

local persist_dir = h.temp_dir('hlcraft-ui-render')
hlcraft.setup({
  persistence = {
    dir = persist_dir,
    reapply_events = {
      enabled = false,
    },
  },
  search = {
    debounce_ms = 0,
  },
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

local function new_detail_render_instance(buf, namespace)
  local instance = {
    ns = vim.api.nvim_create_namespace(namespace),
    input_ns = vim.api.nvim_create_namespace(namespace .. '-input'),
    state = ui_state.initial(),
  }
  instance.state.buf = buf
  instance.state.last_workspace_win = vim.api.nvim_get_current_win()
  instance.state.detail_index = 1
  instance.state.results = {
    result,
  }
  return instance
end

local function register_old_dynamic_preview(instance, dynamic)
  local previous_id = dynamic_preview.register(instance, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'OLDX',
    base = '#000000',
    dynamic = dynamic,
  })
  dynamic_preview.tick(instance, 0)
  return previous_id,
    vim.deepcopy(instance.state.dynamic_preview.items),
    vim.deepcopy(instance.state.dynamic_preview.marks)
end

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

local dynamic = dynamic_model.normalize_channel({
  version = 1,
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
  },
})
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
  assert_preview_range(
    dynamic_detail_lines,
    dynamic_detail_instance.state.dynamic_preview.items[1],
    'detail dynamic preview'
  )
end)

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'OLDX' })
  local render_failure_instance = new_detail_render_instance(buf, 'hlcraft-ui-render-dynamic-failure-test')
  local previous_id, previous_items, previous_marks = register_old_dynamic_preview(render_failure_instance, dynamic)
  local previous_mark =
    vim.api.nvim_buf_get_extmark_by_id(buf, render_failure_instance.ns, previous_marks[previous_id], {})

  local original_set_lines = vim.api.nvim_buf_set_lines
  vim.api.nvim_buf_set_lines = function()
    error('set lines failed')
  end
  local failed_dynamic_render_ok = pcall(detail_renderer.render, render_failure_instance)
  vim.api.nvim_buf_set_lines = original_set_lines

  h.assert_true(not failed_dynamic_render_ok, 'detail render accepted failed buffer write', scope)
  h.assert_true(
    vim.deep_equal(render_failure_instance.state.dynamic_preview.items, previous_items),
    'failed detail render replaced dynamic preview items',
    scope
  )
  h.assert_true(
    vim.deep_equal(render_failure_instance.state.dynamic_preview.marks, previous_marks),
    'failed detail render replaced dynamic preview marks',
    scope
  )
  local preserved_mark =
    vim.api.nvim_buf_get_extmark_by_id(buf, render_failure_instance.ns, previous_marks[previous_id], {})
  h.assert_true(
    vim.deep_equal(preserved_mark, previous_mark),
    'failed detail render dropped old dynamic preview mark',
    scope
  )
end, { current = true })

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'OLDX' })
  local finish_failure_instance = new_detail_render_instance(buf, 'hlcraft-ui-render-dynamic-finish-failure-test')
  local previous_id, previous_items, previous_marks = register_old_dynamic_preview(finish_failure_instance, dynamic)
  local previous_mark_id = previous_marks[previous_id]

  local original_set_extmark = vim.api.nvim_buf_set_extmark
  vim.api.nvim_buf_set_extmark = function()
    error('finish extmark failed')
  end
  local failed_finish_render_ok = pcall(detail_renderer.render, finish_failure_instance)
  vim.api.nvim_buf_set_extmark = original_set_extmark

  h.assert_true(not failed_finish_render_ok, 'detail render accepted failed finish', scope)
  h.assert_equal(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
    'OLDX',
    'finish-failed detail render kept partially rendered buffer content',
    scope
  )
  h.assert_true(
    vim.deep_equal(finish_failure_instance.state.dynamic_preview.items, previous_items),
    'finish-failed detail render replaced dynamic preview items',
    scope
  )
  h.assert_true(
    finish_failure_instance.state.dynamic_preview.marks[previous_id] == nil,
    'finish-failed detail render kept a stale dynamic preview mark id',
    scope
  )
  local stale_finish_failure_mark =
    vim.api.nvim_buf_get_extmark_by_id(buf, finish_failure_instance.ns, previous_mark_id, {})
  h.assert_true(
    #stale_finish_failure_mark == 0,
    'finish-failed detail render kept a stale dynamic preview extmark',
    scope
  )
  dynamic_preview.tick(finish_failure_instance, 0)
  local finish_failure_restored_mark = vim.api.nvim_buf_get_extmark_by_id(
    buf,
    finish_failure_instance.ns,
    finish_failure_instance.state.dynamic_preview.marks[previous_id],
    {}
  )
  h.assert_true(
    #finish_failure_restored_mark > 0,
    'finish-failed detail render could not rebuild the previous dynamic preview extmark',
    scope
  )
end, { current = true })

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'OLDX' })
  local decoration_failure_instance =
    new_detail_render_instance(buf, 'hlcraft-ui-render-dynamic-decoration-failure-test')
  local previous_id, previous_items, previous_marks = register_old_dynamic_preview(decoration_failure_instance, dynamic)

  local original_set_extmark = vim.api.nvim_buf_set_extmark
  vim.api.nvim_buf_set_extmark = function(target_buf, ns, line, col, opts)
    if type(opts) == 'table' and opts.virt_lines ~= nil then
      error('decoration extmark failed')
    end
    return original_set_extmark(target_buf, ns, line, col, opts)
  end
  local failed_decoration_render_ok = pcall(detail_renderer.render, decoration_failure_instance)
  vim.api.nvim_buf_set_extmark = original_set_extmark

  h.assert_true(not failed_decoration_render_ok, 'detail render accepted failed decoration', scope)
  h.assert_equal(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
    'OLDX',
    'decoration-failed detail render kept partially rendered buffer content',
    scope
  )
  h.assert_true(
    vim.deep_equal(decoration_failure_instance.state.dynamic_preview.items, previous_items),
    'decoration-failed detail render replaced dynamic preview items',
    scope
  )
  h.assert_true(
    vim.deep_equal(decoration_failure_instance.state.dynamic_preview.marks, previous_marks),
    'decoration-failed detail render replaced dynamic preview marks',
    scope
  )
  h.assert_true(
    #vim.api.nvim_buf_get_extmark_by_id(
        buf,
        decoration_failure_instance.ns,
        decoration_failure_instance.state.dynamic_preview.marks[previous_id],
        {}
      ) > 0,
    'decoration-failed detail render did not restore the previous dynamic preview extmark',
    scope
  )
end, { current = true })

engine.clear('HlcraftUiRenderNormal')
h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui render: OK')
