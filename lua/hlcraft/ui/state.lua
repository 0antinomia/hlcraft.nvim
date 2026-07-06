local M = {}

local function assert_target(target, label)
  if type(target) ~= 'table' then
    error(('%s state target must be a table'):format(label), 3)
  end
  return target
end

function M.geometry()
  return {
    inputs = {},
    result_cells = {},
    result_lines = {},
    detail_menu = {},
    editor_rows = {},
  }
end

function M.field_editor()
  return {
    field = nil,
  }
end

function M.unsaved_prompt()
  return {
    win = nil,
    buf = nil,
  }
end

function M.preview()
  return {
    name = nil,
    spec = nil,
    timer = nil,
    keymap = nil,
  }
end

function M.dynamic_preview()
  return {
    marks = {},
    items = {},
    timer = nil,
    instance_id = nil,
  }
end

function M.raw_dynamic()
  return {
    win = nil,
    buf = nil,
  }
end

function M.search_scene()
  return {
    name = 'search',
  }
end

function M.initial()
  local state = {}
  M.reset_workspace_handles(state)
  M.reset_view(state)
  M.reset_lifecycle(state)
  return state
end

function M.reset_view(target)
  target = assert_target(target, 'view reset')
  target.results = {}
  target.detail_index = nil
  target.list_cursor = 1
  target.name_query = ''
  target.color_query = ''
  target.geometry = M.geometry()
  target.field_editor = M.field_editor()
  target.unsaved_prompt = M.unsaved_prompt()
  target.rendering = false
  target.input_marks = {}
  target.placeholder_marks = {}
  target.extmark_ids = {}
  target.clamping_cursor = false
  target.preview = M.preview()
  target.dynamic_preview = M.dynamic_preview()
  target.raw_dynamic = M.raw_dynamic()
  target.scene = M.search_scene()
end

function M.reset_workspace_handles(target)
  target = assert_target(target, 'workspace reset')
  target.buf = nil
  target.help_buf = nil
  target.help_win = nil
  target.origin_buf = nil
  target.origin_win = nil
  target.origin_win_options = nil
  target.workspace_win_options = {}
  target.last_workspace_win = nil
end

function M.reset_lifecycle(target)
  target = assert_target(target, 'lifecycle reset')
  target.closing = false
  target.debounce_timer = nil
end

return M
