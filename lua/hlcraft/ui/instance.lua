local scene = require('hlcraft.ui.scene')
local state = require('hlcraft.ui.state')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local theme = require('hlcraft.ui.theme')

scene.register('detail', require('hlcraft.ui.scene.detail'))
scene.register('field_editor', require('hlcraft.ui.scene.field_editor'))
scene.register('search', require('hlcraft.ui.scene.search'))

local ns = vim.api.nvim_create_namespace('hlcraft-ui')

local input_label_hl = theme.groups.label

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
  self.state = state.initial()
  self.ns = ns
  self.input_label_hl = input_label_hl
  return self
end

--- Update search results and re-render the workspace buffer
--- @return nil
function Instance:rerender()
  scene.render(self)
end

--- Close detail view if open, otherwise close the entire workspace
--- @return nil
function Instance:quit_or_back()
  scene.back(self)
end

--- Open the workspace in the current window
--- @return nil
function Instance:open()
  return lifecycle.open(self)
end

--- Clean up all resources: windows, buffers, augroups, and reset state
--- @return nil
function Instance:cleanup()
  return lifecycle.cleanup(self)
end

return Instance
