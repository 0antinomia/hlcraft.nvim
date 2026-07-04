local h = require('tests.helpers')
local scope = 'hlcraft ui state'

local ui_state = require('hlcraft.ui.state')

local first = ui_state.initial()
local second = ui_state.initial()

h.assert_equal(first.list_cursor, 1, 'initial list cursor changed', scope)
h.assert_equal(first.name_query, '', 'initial name query changed', scope)
h.assert_equal(first.color_query, '', 'initial color query changed', scope)
h.assert_equal(first.scene.name, 'search', 'initial scene changed', scope)
h.assert_true(first.field_editor.field == nil, 'initial field editor field was not nil', scope)
h.assert_true(first.workspace_win_options ~= second.workspace_win_options, 'workspace handle state was shared', scope)
h.assert_true(first.results ~= second.results, 'result state was shared', scope)
h.assert_true(first.geometry.inputs ~= second.geometry.inputs, 'geometry state was shared', scope)
h.assert_true(first.preview ~= second.preview, 'preview state was shared', scope)
h.assert_true(first.dynamic_preview ~= second.dynamic_preview, 'dynamic preview state was shared', scope)
h.assert_true(first.dynamic_preview.marks ~= second.dynamic_preview.marks, 'dynamic preview marks were shared', scope)
h.assert_true(first.dynamic_preview.items ~= second.dynamic_preview.items, 'dynamic preview items were shared', scope)

local timer = {}
local state = ui_state.initial()
state.buf = 11
state.help_buf = 12
state.help_win = 13
state.origin_buf = 14
state.origin_win = 15
state.origin_win_options = { values = { number = true } }
state.workspace_win_options = { [21] = { values = { wrap = false } } }
state.last_workspace_win = 21
state.closing = true
state.debounce_timer = timer

state.results = { { name = 'Changed' } }
state.detail_index = 2
state.list_cursor = 9
state.name_query = 'name'
state.color_query = '#fff'
state.geometry.inputs = { { line = 1 } }
state.geometry.result_lines = { [4] = 1 }
state.geometry.detail_menu = { fg = { line = 5 } }
state.geometry.editor_rows = { fg = { line = 6 } }
state.field_editor = { field = 'bg', stale_extra = 3 }
state.unsaved_prompt = { win = 31, buf = 32 }
state.rendering = true
state.input_marks = { name = 41 }
state.placeholder_marks = { color = 42 }
state.extmark_ids = { dirty = 43 }
state.clamping_cursor = true
state.preview = { name = 'Changed', spec = {}, timer = {}, keymap = {} }
state.dynamic_preview = {
  marks = { [1] = 51 },
  items = { { id = 1 } },
  timer = {},
  instance_id = 7,
}
state.scene = { name = 'detail', index = 2 }

ui_state.reset_view(state)

h.assert_equal(state.buf, 11, 'view reset cleared workspace buffer handle', scope)
h.assert_equal(state.help_buf, 12, 'view reset cleared help buffer handle', scope)
h.assert_equal(state.help_win, 13, 'view reset cleared help window handle', scope)
h.assert_equal(state.origin_buf, 14, 'view reset cleared origin buffer handle', scope)
h.assert_equal(state.origin_win, 15, 'view reset cleared origin window handle', scope)
h.assert_true(state.origin_win_options ~= nil, 'view reset cleared origin window options', scope)
h.assert_true(state.workspace_win_options[21] ~= nil, 'view reset cleared workspace window options', scope)
h.assert_equal(state.last_workspace_win, 21, 'view reset cleared last workspace window', scope)
h.assert_true(state.closing, 'view reset cleared closing guard', scope)
h.assert_true(state.debounce_timer == timer, 'view reset cleared debounce timer', scope)

h.assert_true(next(state.results) == nil, 'view reset kept search results', scope)
h.assert_true(state.detail_index == nil, 'view reset kept detail index', scope)
h.assert_equal(state.list_cursor, 1, 'view reset changed list cursor default', scope)
h.assert_equal(state.name_query, '', 'view reset kept name query', scope)
h.assert_equal(state.color_query, '', 'view reset kept color query', scope)
h.assert_true(next(state.geometry.inputs) == nil, 'view reset kept input geometry', scope)
h.assert_true(next(state.geometry.result_lines) == nil, 'view reset kept result geometry', scope)
h.assert_true(next(state.geometry.detail_menu) == nil, 'view reset kept detail menu geometry', scope)
h.assert_true(next(state.geometry.editor_rows) == nil, 'view reset kept editor row geometry', scope)
h.assert_true(state.field_editor.field == nil, 'view reset kept field editor field', scope)
h.assert_true(state.field_editor.stale_extra == nil, 'view reset kept stale field editor state', scope)
h.assert_true(state.unsaved_prompt.win == nil, 'view reset kept unsaved prompt window', scope)
h.assert_true(state.unsaved_prompt.buf == nil, 'view reset kept unsaved prompt buffer', scope)
h.assert_true(not state.rendering, 'view reset kept rendering flag', scope)
h.assert_true(next(state.input_marks) == nil, 'view reset kept input marks', scope)
h.assert_true(next(state.placeholder_marks) == nil, 'view reset kept placeholder marks', scope)
h.assert_true(next(state.extmark_ids) == nil, 'view reset kept extmark ids', scope)
h.assert_true(not state.clamping_cursor, 'view reset kept cursor clamp flag', scope)
h.assert_true(state.preview.name == nil, 'view reset kept preview name', scope)
h.assert_true(state.preview.spec == nil, 'view reset kept preview spec', scope)
h.assert_true(state.preview.timer == nil, 'view reset kept preview timer', scope)
h.assert_true(state.preview.keymap == nil, 'view reset kept preview keymap', scope)
h.assert_true(next(state.dynamic_preview.marks) == nil, 'view reset kept dynamic preview marks', scope)
h.assert_true(next(state.dynamic_preview.items) == nil, 'view reset kept dynamic preview items', scope)
h.assert_true(state.dynamic_preview.timer == nil, 'view reset kept dynamic preview timer', scope)
h.assert_true(state.dynamic_preview.instance_id == nil, 'view reset kept dynamic preview instance id', scope)
h.assert_equal(state.scene.name, 'search', 'view reset did not return to search scene', scope)

state.closing = true
state.debounce_timer = timer
ui_state.reset_workspace_handles(state)

h.assert_true(state.buf == nil, 'workspace reset kept buffer handle', scope)
h.assert_true(state.help_buf == nil, 'workspace reset kept help buffer handle', scope)
h.assert_true(state.help_win == nil, 'workspace reset kept help window handle', scope)
h.assert_true(state.origin_buf == nil, 'workspace reset kept origin buffer handle', scope)
h.assert_true(state.origin_win == nil, 'workspace reset kept origin window handle', scope)
h.assert_true(state.origin_win_options == nil, 'workspace reset kept origin window options', scope)
h.assert_true(next(state.workspace_win_options) == nil, 'workspace reset kept window snapshots', scope)
h.assert_true(state.last_workspace_win == nil, 'workspace reset kept last workspace window', scope)
h.assert_true(state.closing, 'workspace reset changed lifecycle guard', scope)
h.assert_true(state.debounce_timer == timer, 'workspace reset changed debounce timer', scope)

print('hlcraft ui state: OK')
