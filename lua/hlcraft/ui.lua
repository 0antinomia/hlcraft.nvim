local UiInstance = require('hlcraft.ui.instance')

local M = {}

local instances = {}

--- Get or create a named UI instance
--- @param name string|nil Instance identifier, defaults to 'default'
--- @return table Instance object
function M.get_instance(name)
  local key = name or 'default'
  if not instances[key] then
    instances[key] = UiInstance.new(key)
  end
  return instances[key]
end

--- Open the hlcraft UI explorer
--- @param opts table|nil Options with optional instance_name field
--- @return nil
function M.open(opts)
  opts = opts or {}
  M.get_instance(opts.instance_name):open()
end

return M
