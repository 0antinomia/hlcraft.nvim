local UiInstance = require('hlcraft.ui.instance')

local M = {}

local instances = {}

local function assert_instance_name(name)
  if name ~= nil and (type(name) ~= 'string' or name == '') then
    error('UI instance name must be a non-empty string or nil', 3)
  end
  return name
end

local function optional_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error('UI open options must be a table', 3)
  end
  for key in pairs(opts) do
    if key ~= 'instance_name' then
      error(('unknown UI open option: %s'):format(tostring(key)), 3)
    end
  end
  assert_instance_name(opts.instance_name)
  return opts
end

--- Get or create a named UI instance
--- @param name string|nil Instance identifier, defaults to 'default'
--- @return table Instance object
function M.get_instance(name)
  name = assert_instance_name(name)
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
  opts = optional_opts(opts)
  M.get_instance(opts.instance_name):open()
end

return M
