local results_state = require('hlcraft.ui.state.results')
local workspace = require('hlcraft.ui.workspace')
local workspace_render = require('hlcraft.ui.render.workspace')

local ns = vim.api.nvim_create_namespace('hlcraft-ui')

local input_label_hl = 'HlcraftInputLabel'

local Instance = {}
Instance.__index = Instance

--- Create a new Instance object with initialized state
--- @param id string|nil Instance identifier, defaults to 'default'
--- @return table New Instance object
function Instance.new(id)
  local self = setmetatable({}, Instance)
  self.id = id or 'default'
  self.group_name = 'HlcraftUi-' .. self.id
  self.group = nil
  self.state = {
    buf = nil,
    help_buf = nil,
    help_win = nil,
    origin_buf = nil,
    origin_win = nil,
    origin_win_options = nil,
    workspace_win_options = {},
    last_workspace_win = nil,
    results = {},
    detail_index = nil,
    list_cursor = 1,
    name_query = '',
    color_query = '',
    geometry = {
      inputs = {},
      result_lines = {},
      detail_fields = {},
      detail_menu = {},
      editor_rows = {},
    },
    detail_form = {},
    field_editor = {
      field = nil,
    },
    unsaved_prompt = {
      win = nil,
      buf = nil,
    },
    rendering = false,
    input_marks = {},
    placeholder_marks = {},
    extmark_ids = {},
    clamping_cursor = false,
    closing = false,
    debounce_timer = nil,
    preview = {
      name = nil,
      spec = nil,
      timer = nil,
      keymap = nil,
    },
  }
  self.ns = ns
  self.input_label_hl = input_label_hl
  return self
end

--- Update search results and re-render the workspace buffer
--- @return nil
function Instance:rerender()
  results_state.update_results(self)
  workspace_render.render(self)
end

--- Close detail view if open, otherwise close the entire workspace
--- @return nil
function Instance:quit_or_back()
  if self.state.detail_index then
    results_state.close_detail(self)
    return
  end

  workspace.close(self)
end

--- Open the workspace in the current window
--- @return nil
function Instance:open()
  return workspace.open(self)
end

--- Close the workspace window and restore origin buffer
--- @return nil
function Instance:close_workspace()
  return workspace.close(self)
end

--- Clean up all resources: windows, buffers, augroups, and reset state
--- @return nil
function Instance:cleanup()
  return workspace.cleanup(self)
end

return Instance
