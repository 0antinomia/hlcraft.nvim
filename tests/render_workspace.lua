local h = require('tests.helpers')
local scope = 'hlcraft render workspace'

local list = require('hlcraft.ui.render.list')
local detail_menu = require('hlcraft.ui.render.detail_menu')
local field_editor = require('hlcraft.ui.render.field_editor')
local detail_values = require('hlcraft.ui.state.detail_values')

local list_lines, selectable = list.build({
  state = {
    results = {
      { name = 'Normal', fg = '#111111', bg = 'NONE', sp = 'NONE' },
    },
  },
}, 80)
h.assert_true(list_lines[1]:find('NAME') ~= nil, 'list header did not render', scope)
h.assert_equal(selectable[3], 1, 'list selectable row was not registered', scope)

h.assert_equal(detail_menu.display_text(nil), 'unset', 'nil detail value display is wrong', scope)
h.assert_equal(detail_menu.display_text(true), 'true', 'true detail value display is wrong', scope)
h.assert_equal(detail_menu.display_text(false), 'false', 'false detail value display is wrong', scope)

local result = {
  name = 'HlcraftRenderNormal',
  fg = '#111111',
  bg = 'NONE',
  sp = 'NONE',
  resolved_fg = '#111111',
  resolved_bg = 'NONE',
}
local menu_geometry = {
  detail_menu = {},
}
local menu_lines = detail_menu.build(menu_geometry, result, 80)
h.assert_true(menu_lines[1]:find('Detail fields') ~= nil, 'detail menu title did not render', scope)
h.assert_true(menu_geometry.detail_menu.group ~= nil, 'detail group row was not registered', scope)

local editor_geometry = {
  editor_rows = {},
}
local blend_lines = field_editor.build(editor_geometry, result, 'blend', 80)
h.assert_true(blend_lines[1]:find('Blend editor') ~= nil, 'blend editor did not render', scope)
h.assert_true(editor_geometry.editor_rows.blend_keys ~= nil, 'blend editor key row was not registered', scope)

local dynamic_result = {
  name = 'HlcraftRenderDynamic',
  fg = '#111111',
  bg = 'NONE',
  sp = 'NONE',
  resolved_fg = '#111111',
  resolved_bg = 'NONE',
}

local overrides = require('hlcraft.overrides')
local dynamic_group_ok, dynamic_group_err = overrides.set_group('HlcraftRenderDynamic', 'render')
h.assert_true(dynamic_group_ok, dynamic_group_err or 'failed to set render dynamic group', scope)
local dynamic_set_ok, dynamic_set_err = overrides.set_dynamic('HlcraftRenderDynamic', 'fg', {
  mode = 'rgb',
  speed = 1500,
})
h.assert_true(dynamic_set_ok, dynamic_set_err or 'failed to set render dynamic fg', scope)

local dynamic_geometry = {
  detail_menu = {},
}
local dynamic_menu_lines = detail_menu.build(dynamic_geometry, dynamic_result, 80)
h.assert_true(
  table.concat(dynamic_menu_lines, '\n'):find('dynamic:rgb', 1, true) == nil,
  'detail menu still used old dynamic string primary display',
  scope
)
h.assert_true(
  table.concat(dynamic_menu_lines, '\n'):find('rgb 1500ms', 1, true) ~= nil,
  'detail menu did not render compact dynamic metadata',
  scope
)

local dynamic_editor_geometry = {
  editor_rows = {},
}
local dynamic_editor_lines = field_editor.build(dynamic_editor_geometry, dynamic_result, 'fg', 80)
local dynamic_editor_text = table.concat(dynamic_editor_lines, '\n')
h.assert_true(dynamic_editor_text:find('Mode: dynamic', 1, true) ~= nil, 'dynamic editor mode missing', scope)
h.assert_true(dynamic_editor_text:find('Effect: rgb', 1, true) ~= nil, 'dynamic editor effect missing', scope)
h.assert_true(dynamic_editor_text:find('Speed: 1500ms', 1, true) ~= nil, 'dynamic editor speed missing', scope)
h.assert_true(dynamic_editor_text:find('Swatch:', 1, true) ~= nil, 'dynamic editor swatch missing', scope)
h.assert_true(dynamic_editor_text:find('Preview:', 1, true) == nil, 'dynamic editor still rendered preview row', scope)
h.assert_true(dynamic_editor_geometry.editor_rows.dynamic_keys ~= nil, 'dynamic editor keys row missing', scope)

local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local Instance = require('hlcraft.ui.instance')
local results_state = require('hlcraft.ui.state.results')
local workspace_instance = Instance.new('render-workspace-dynamic-swatch')
vim.api.nvim_set_hl(0, 'HlcraftRenderTarget', { fg = '#112233' })
workspace_instance:open()
workspace_instance.state.name_query = 'HlcraftRenderTarget'
workspace_instance:rerender()
local workspace_target_line = h.find_result_line(workspace_instance, 1)
h.assert_true(workspace_target_line ~= nil, 'failed to find render target result', scope)
local workspace_win = vim.fn.bufwinid(workspace_instance.state.buf)
h.assert_true(workspace_win ~= -1, 'render workspace window is not visible', scope)
vim.api.nvim_win_set_cursor(workspace_win, { workspace_target_line, 0 })
results_state.open_detail(workspace_instance)
local dynamic_apply_ok, dynamic_apply_err = detail_values.apply_runtime(workspace_instance, 'HlcraftRenderTarget', {
  dynamic = {
    fg = {
      mode = 'rgb',
      speed = 2000,
      palette = { '#000000', '#ffffff' },
    },
  },
})
h.assert_true(dynamic_apply_ok, dynamic_apply_err or 'failed to seed render dynamic fg', scope)
workspace_instance:rerender()
local dynamic_render_text = table.concat(vim.api.nvim_buf_get_lines(workspace_instance.state.buf, 0, -1, false), '\n')
h.assert_true(
  dynamic_render_text:find('dynamic:rgb', 1, true) == nil,
  'dynamic detail row still used old dynamic string primary display',
  scope
)
h.assert_true(
  dynamic_render_text:find('rgb 2000ms', 1, true) ~= nil,
  'dynamic detail row did not render compact metadata',
  scope
)
h.assert_true(
  workspace_instance.state.dynamic_preview_items ~= nil and next(workspace_instance.state.dynamic_preview_items) ~= nil,
  'dynamic detail row did not register preview swatch',
  scope
)
local workspace_buf = workspace_instance.state.buf
workspace_instance:cleanup()
h.assert_true(not vim.api.nvim_buf_is_valid(workspace_buf), 'workspace cleanup left owned render buffer alive', scope)
require('hlcraft.highlights').invalidate_cache()

local preview_instance = {
  ns = vim.api.nvim_create_namespace('hlcraft-preview-test'),
  state = {
    buf = vim.api.nvim_create_buf(false, true),
    dynamic_preview_marks = {},
  },
}
vim.api.nvim_buf_set_lines(preview_instance.state.buf, 0, -1, false, {
  'Preview:          ',
})
local unrelated_preview_mark = vim.api.nvim_buf_set_extmark(preview_instance.state.buf, preview_instance.ns, 0, 0, {
  virt_text = { { 'keep', 'Normal' } },
  virt_text_pos = 'eol',
})

local preview_id = dynamic_preview.register(preview_instance, {
  line = 1,
  col_start = 9,
  col_end = 17,
  text = '████████',
  field = 'fg',
  base = '#000000',
  dynamic = {
    mode = 'rgb',
    speed = 2000,
    palette = { '#000000', '#ffffff' },
  },
})
h.assert_true(type(preview_id) == 'number', 'dynamic preview did not return extmark id', scope)
dynamic_preview.tick(preview_instance, 500)
local marks = vim.api.nvim_buf_get_extmarks(preview_instance.state.buf, preview_instance.ns, 0, -1, { details = true })
local preview_mark = nil
for _, mark in ipairs(marks) do
  if mark[4].virt_text and mark[4].virt_text[1] and mark[4].virt_text[1][1] == '████████' then
    preview_mark = mark
    break
  end
end
h.assert_true(#marks > 0, 'dynamic preview did not create extmark', scope)
h.assert_true(preview_mark ~= nil, 'dynamic preview mark was not found', scope)
local unrelated_mark_after_tick = vim.api.nvim_buf_get_extmark_by_id(
  preview_instance.state.buf,
  preview_instance.ns,
  unrelated_preview_mark,
  { details = true }
)
h.assert_true(
  #unrelated_mark_after_tick > 0 and unrelated_mark_after_tick[3].virt_text[1][1] == 'keep',
  'dynamic preview tick removed unrelated extmark',
  scope
)
h.assert_equal(
  preview_mark[4].virt_text[1][1],
  '████████',
  'dynamic preview did not preserve swatch text',
  scope
)
h.assert_true(
  preview_mark[4].virt_text[1][2]:find('HlcraftDynamicPreview', 1, true) == 1,
  'dynamic preview did not use generated highlight group',
  scope
)
vim.api.nvim_buf_clear_namespace(preview_instance.state.buf, preview_instance.ns, 0, -1)
local reused_id = vim.api.nvim_buf_set_extmark(preview_instance.state.buf, preview_instance.ns, 0, 0, {
  id = preview_mark[1],
  virt_text = { { 'reused', 'Normal' } },
  virt_text_pos = 'eol',
})
dynamic_preview.tick(preview_instance, 1000)
local reused_mark_after_tick =
  vim.api.nvim_buf_get_extmark_by_id(preview_instance.state.buf, preview_instance.ns, reused_id, { details = true })
h.assert_true(
  #reused_mark_after_tick > 0 and reused_mark_after_tick[3].virt_text[1][1] == 'reused',
  'dynamic preview tick deleted unrelated extmark after namespace clear reused a stale preview mark id',
  scope
)
dynamic_preview.clear(preview_instance)
local reused_mark_after_clear =
  vim.api.nvim_buf_get_extmark_by_id(preview_instance.state.buf, preview_instance.ns, reused_id, { details = true })
h.assert_true(
  #reused_mark_after_clear > 0 and reused_mark_after_clear[3].virt_text[1][1] == 'reused',
  'dynamic preview clear removed unrelated extmark after namespace clear reused a stale preview mark id',
  scope
)
local marks_after_clear = vim.api.nvim_buf_get_extmarks(preview_instance.state.buf, preview_instance.ns, 0, -1, {
  details = true,
})
for _, mark in ipairs(marks_after_clear) do
  h.assert_true(
    not (mark[4].virt_text and mark[4].virt_text[1] and mark[4].virt_text[1][1] == '████████'),
    'dynamic preview clear left preview extmarks behind',
    scope
  )
end
vim.api.nvim_buf_delete(preview_instance.state.buf, { force = true })

local timer_instance_one = {
  ns = vim.api.nvim_create_namespace('hlcraft-preview-test-timer-one'),
  state = {
    buf = vim.api.nvim_create_buf(false, true),
  },
}
local timer_instance_two = {
  ns = vim.api.nvim_create_namespace('hlcraft-preview-test-timer-two'),
  state = {
    buf = vim.api.nvim_create_buf(false, true),
  },
}
vim.api.nvim_buf_set_lines(timer_instance_one.state.buf, 0, -1, false, { 'Timer one:          ' })
vim.api.nvim_buf_set_lines(timer_instance_two.state.buf, 0, -1, false, { 'Timer two:          ' })
dynamic_preview.register(timer_instance_one, {
  line = 1,
  col_start = 11,
  col_end = 19,
  text = '████████',
  base = '#000000',
  dynamic = {
    mode = 'rgb',
    speed = 2000,
    palette = { '#000000', '#ffffff' },
  },
})
dynamic_preview.register(timer_instance_two, {
  line = 1,
  col_start = 11,
  col_end = 19,
  text = '████████',
  base = '#000000',
  dynamic = {
    mode = 'rgb',
    speed = 2000,
    palette = { '#000000', '#ffffff' },
  },
})
dynamic_preview.sync(timer_instance_one)
local first_preview_timer = timer_instance_one.state.dynamic_preview_timer
dynamic_preview.sync(timer_instance_two)
local second_preview_timer = timer_instance_two.state.dynamic_preview_timer
dynamic_preview.clear(timer_instance_one)
local second_timer_after_first_clear = timer_instance_two.state.dynamic_preview_timer
dynamic_preview.clear(timer_instance_two)
vim.api.nvim_buf_delete(timer_instance_one.state.buf, { force = true })
vim.api.nvim_buf_delete(timer_instance_two.state.buf, { force = true })
h.assert_true(first_preview_timer ~= nil, 'dynamic preview sync did not store first timer on instance', scope)
h.assert_true(second_preview_timer ~= nil, 'dynamic preview sync did not store second timer on instance', scope)
h.assert_true(first_preview_timer ~= second_preview_timer, 'dynamic preview sync reused timer between instances', scope)
h.assert_equal(
  second_timer_after_first_clear,
  second_preview_timer,
  'dynamic preview clear stopped another instance timer',
  scope
)

local shared_instance_one = Instance.new('dynamic-preview-one')
local shared_instance_two = Instance.new('dynamic_preview_one')
shared_instance_one.state.buf = vim.api.nvim_create_buf(false, true)
shared_instance_two.state.buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(shared_instance_one.state.buf, 0, -1, false, { 'Shared one:          ' })
vim.api.nvim_buf_set_lines(shared_instance_two.state.buf, 0, -1, false, { 'Shared two:          ' })
local shared_preview_one = dynamic_preview.register(shared_instance_one, {
  line = 1,
  col_start = 12,
  col_end = 20,
  text = '████████',
  base = '#000000',
  dynamic = {
    mode = 'rgb',
    speed = 2000,
    palette = { '#000000', '#ffffff' },
  },
})
local shared_preview_two = dynamic_preview.register(shared_instance_two, {
  line = 1,
  col_start = 12,
  col_end = 20,
  text = '████████',
  base = '#000000',
  dynamic = {
    mode = 'rgb',
    speed = 2000,
    palette = { '#000000', '#ffffff' },
  },
})
h.assert_equal(shared_preview_one, 1, 'first shared namespace preview did not start at item id 1', scope)
h.assert_equal(shared_preview_two, 1, 'second shared namespace preview did not start at item id 1', scope)
dynamic_preview.tick(shared_instance_one, 0)
dynamic_preview.tick(shared_instance_two, 1000)
local shared_one_marks =
  vim.api.nvim_buf_get_extmarks(shared_instance_one.state.buf, shared_instance_one.ns, 0, -1, { details = true })
local shared_two_marks =
  vim.api.nvim_buf_get_extmarks(shared_instance_two.state.buf, shared_instance_two.ns, 0, -1, { details = true })
local shared_one_hl = shared_one_marks[1][4].virt_text[1][2]
local shared_two_hl = shared_two_marks[1][4].virt_text[1][2]
local shared_one_hl_spec = vim.api.nvim_get_hl(shared_instance_one.ns, { name = shared_one_hl, link = false })
local shared_two_hl_spec = vim.api.nvim_get_hl(shared_instance_two.ns, { name = shared_two_hl, link = false })
vim.api.nvim_buf_delete(shared_instance_one.state.buf, { force = true })
vim.api.nvim_buf_delete(shared_instance_two.state.buf, { force = true })
h.assert_true(shared_one_hl ~= shared_two_hl, 'dynamic preview shared namespace highlight names collided', scope)
h.assert_true(
  shared_one_hl_spec.fg ~= shared_two_hl_spec.fg,
  'dynamic preview shared namespace highlight groups were overwritten',
  scope
)

print('hlcraft render workspace: OK')
