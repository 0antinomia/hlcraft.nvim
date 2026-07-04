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

  local merged = vim.tbl_deep_extend('force', vim.deepcopy(schema.defaults), user_config or {})
  M.config = schema.normalize(merged)
  return M.config
end

function M.from_none_enabled()
  return M.config.from_none.enabled == true
end

function M.from_none_scope()
  return M.config.from_none.scope
end

return M
