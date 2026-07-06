local M = {}

local schema = require('hlcraft.config.schema')

M.config = vim.deepcopy(schema.defaults)

function M.validate(user_config)
  return schema.validate(user_config)
end

function M.setup(user_config)
  local ok, err = schema.validate(user_config)
  if not ok then
    error(err, 2)
  end

  local source = user_config
  if source == nil then
    source = {}
  end
  local merged = vim.tbl_deep_extend('force', vim.deepcopy(schema.defaults), source)
  M.config = schema.normalize(merged)
  return M.config
end

function M.transparent_enabled()
  return M.config.transparent.enabled == true
end

function M.transparent_scope()
  return M.config.transparent.scope
end

return M
