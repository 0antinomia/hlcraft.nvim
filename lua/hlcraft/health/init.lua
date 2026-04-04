--- @type table
local M = {}

local config = require('hlcraft.config')
local storage = require('hlcraft.storage')

--- Run health checks for :checkhealth hlcraft
--- @return nil
function M.check()
  vim.health.start('hlcraft: Neovim version')
  if vim.version.ge(vim.version(), '0.10.0') then
    vim.health.ok('Neovim version ' .. tostring(vim.version()) .. ' >= 0.10.0')
  else
    vim.health.error('hlcraft requires Neovim >= 0.10.0, found ' .. tostring(vim.version()))
  end

  vim.health.start('hlcraft: persist directory')
  local dir = config.config.persist_dir
  local stat = vim.uv.fs_stat(dir)
  if not stat then
    vim.health.ok('persist_dir not yet created (will be created on first save): ' .. dir)
  else
    vim.health.ok('persist_dir: ' .. dir)
    local test_file = dir .. '/.hlcraft_health_check'
    local file = io.open(test_file, 'w')
    if file then
      file:close()
      os.remove(test_file)
      vim.health.ok('persist_dir is writable')
    else
      vim.health.error('persist_dir is not writable: ' .. dir)
    end
  end

  vim.health.start('hlcraft: TOML file integrity')
  if not stat then
    vim.health.ok('No TOML files to check (persist_dir does not exist yet)')
  else
    local ok, data = pcall(storage.load, dir)
    if ok then
      local count = 0
      for _ in pairs(data.entries or {}) do
        count = count + 1
      end
      vim.health.ok(('All TOML files parsed successfully (%d entries)'):format(count))
    else
      vim.health.error('Failed to parse TOML files: ' .. tostring(data))
    end
  end
end

return M
