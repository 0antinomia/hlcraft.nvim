--- @type table
local M = {}

local config = require('hlcraft.config')
local neovim = require('hlcraft.neovim')
local storage = require('hlcraft.persistence.repository')

local function loaded_entries(data)
  if type(data) ~= 'table' or type(data.entries) ~= 'table' then
    return nil
  end
  return data.entries
end

--- Run health checks for :checkhealth hlcraft
--- @return nil
function M.check()
  vim.health.start('hlcraft: Neovim version')
  local supported, version = neovim.supports_minimum()
  if supported then
    vim.health.ok(('Neovim version %s >= %s'):format(tostring(version), neovim.minimum_version))
  else
    vim.health.error('hlcraft ' .. neovim.requirement_message(version))
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
      local entries = loaded_entries(data)
      if not entries then
        vim.health.error('Parsed TOML data is invalid')
      else
        local count = 0
        for _ in pairs(entries) do
          count = count + 1
        end
        vim.health.ok(('All TOML files parsed successfully (%d entries)'):format(count))
        local dynamic_count = 0
        for _, entry in pairs(entries) do
          if type(entry.dynamic) == 'table' and next(entry.dynamic) ~= nil then
            dynamic_count = dynamic_count + 1
          end
        end
        vim.health.ok(('Dynamic color entries parsed: %d'):format(dynamic_count))
      end
    else
      vim.health.error('Failed to parse TOML files: ' .. tostring(data))
    end
  end

  vim.health.start('hlcraft: dynamic colors')
  if config.config.dynamic.enabled then
    vim.health.ok(('dynamic colors enabled, interval %dms'):format(config.config.dynamic.interval_ms))
  else
    vim.health.ok('dynamic colors disabled')
  end
end

return M
