local h = require('tests.helpers')
local scope = 'hlcraft ui render dynamic editor'

local dynamic_model = require('hlcraft.dynamic.model')
local dynamic_renderer = require('hlcraft.ui.render.editors.dynamic')
local ui_state = require('hlcraft.ui.state')

local function assert_preview_range(lines, item, message)
  local line = lines[item.line]
  local start_byte, end_byte = line:find(item.text, 1, true)
  h.assert_true(start_byte ~= nil, message .. ' swatch was not rendered', scope)
  h.assert_equal(item.col_start, start_byte - 1, message .. ' start column changed', scope)
  h.assert_equal(item.col_end, end_byte, message .. ' end column changed', scope)
end

local dynamic = dynamic_model.normalize_channel({
  version = 1,
  preset = 'manual',
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
    { at = 1, color = '#ffffff' },
  },
})

h.with_temp_buf(function(render_buf)
  local render_instance = {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-dynamic-editor-test'),
    state = {
      buf = render_buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  local render_geometry = { editor_rows = {} }
  local render_result = {
    name = 'HlcraftUiRenderDynamicEditorNormal',
    fg = '#101010',
    resolved_fg = '#101010',
    bg = '#202020',
    resolved_bg = '#202020',
    sp = '#303030',
  }
  local render_lines = dynamic_renderer.build(render_instance, render_geometry, render_result, 'fg', 80, 0, dynamic)
  h.assert_true(render_geometry.editor_rows.dynamic_loop ~= nil, 'loop row is not editable', scope)
  h.assert_true(render_geometry.editor_rows.dynamic_phase ~= nil, 'phase row is not editable', scope)
  h.assert_true(render_geometry.editor_rows.dynamic_raw_json ~= nil, 'raw JSON row is not editable', scope)

  local swatch_line = nil
  for index, line in ipairs(render_lines) do
    if line:find('████████████', 1, true) then
      swatch_line = index
      break
    end
  end

  h.assert_equal(
    render_instance.state.dynamic_preview.items[1].line,
    swatch_line,
    'dynamic swatch preview did not track its rendered row',
    scope
  )
  assert_preview_range(render_lines, render_instance.state.dynamic_preview.items[1], 'dynamic swatch preview')
  assert_preview_range(render_lines, render_instance.state.dynamic_preview.items[2], 'dynamic sample preview')
  h.assert_true(
    render_instance.state.dynamic_preview.items[1].field == nil,
    'dynamic swatch preview kept renderer-only field state',
    scope
  )
  h.assert_equal(
    render_instance.state.dynamic_preview.items[1].context.bg,
    '#202020',
    'dynamic swatch preview missed renderer color context',
    scope
  )
  h.assert_true(render_geometry.editor_rows.dynamic_swatch == nil, 'dynamic swatch row should not be selectable', scope)
end)

print('hlcraft ui render dynamic editor: OK')
