--- @type table
local M = {}

local config = require('hlcraft.config')
local highlights = require('hlcraft.highlights')
local source = require('hlcraft.source')
local search = require('hlcraft.search')
local ui = require('hlcraft.ui')
local overrides = require('hlcraft.overrides')
local initialized = false

--- Setup hlcraft.nvim with user configuration
--- @param opts table|nil User configuration options
--- @return table M The hlcraft module (fluent API)
function M.setup(opts)
  -- Version guard
  if vim.version and vim.version.ge then
    if not vim.version.ge(vim.version(), '0.10.0') then
      vim.notify(
        'hlcraft.nvim requires Neovim >= 0.10.0. Current version: ' .. tostring(vim.version()),
        vim.log.levels.ERROR
      )
      return M
    end
  else
    vim.notify('hlcraft.nvim requires Neovim >= 0.10.0', vim.log.levels.ERROR)
    return M
  end

  -- Validate config before merging to prevent partial init.
  local ok, err = config.validate(opts)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return M
  end

  config.setup(opts)
  overrides.bootstrap(true)
  initialized = true
  return M
end

--- Return whether hlcraft has already been initialized via setup().
--- @return boolean
function M.is_setup()
  return initialized
end

-- Submodule access
M.highlights = highlights
M.get_source = source.get_source
M.search = search
M.search_by_name = search.by_name
M.search_by_color = search.by_color
M.overrides = overrides
M.open = function(opts)
  if not initialized then
    M.setup()
  end
  return ui.open(opts)
end

return M
