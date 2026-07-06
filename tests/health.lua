local h = require('tests.helpers')
local scope = 'hlcraft health'

local config = require('hlcraft.config')

local health_module = 'hlcraft.health'
local repository_module = 'hlcraft.persistence.repository'
local original_health_module = package.loaded[health_module]
local original_repository_module = package.loaded[repository_module]
local original_vim_health = vim.health

local function version_api(version)
  return setmetatable({}, {
    __call = function()
      return version
    end,
  })
end

local function with_version(api, fn)
  local original_version = vim.version
  vim.version = api
  local ok, err = xpcall(fn, debug.traceback)
  vim.version = original_version
  if not ok then
    error(err, 0)
  end
end

local messages = {
  error = {},
  ok = {},
  start = {},
}

vim.health = {
  start = function(message)
    messages.start[#messages.start + 1] = message
  end,
  ok = function(message)
    messages.ok[#messages.ok + 1] = message
  end,
  error = function(message)
    messages.error[#messages.error + 1] = message
  end,
}

local persist_dir = h.temp_dir('hlcraft-health')
vim.fn.mkdir(persist_dir, 'p')
config.setup({
  persistence = {
    dir = persist_dir,
  },
})

package.loaded[repository_module] = {
  load = function(path)
    h.assert_equal(path, persist_dir, 'health loaded the wrong persist directory', scope)
    return {
      entries = false,
    }
  end,
}
package.loaded[health_module] = nil

require(health_module).check()

local function contains(list, expected)
  for _, message in ipairs(list) do
    if message == expected then
      return true
    end
  end
  return false
end

h.assert_true(
  contains(messages.error, 'Parsed TOML data is invalid'),
  'health did not report invalid parsed TOML data',
  scope
)
h.assert_true(
  contains(messages.ok, 'persistence.dir: ' .. persist_dir),
  'health reported the old persistence directory config name',
  scope
)
h.assert_true(
  contains(messages.ok, 'dynamic colors stable, interval 80ms'),
  'health stopped before dynamic color check',
  scope
)

local old_version = setmetatable({ major = 0, minor = 9, patch = 5 }, {
  __tostring = function()
    return '0.9.5'
  end,
})
with_version(version_api(old_version), function()
  require(health_module).check()
end)
h.assert_true(
  contains(messages.error, 'hlcraft requires Neovim >= 0.10.0. Current version: 0.9.5'),
  'health did not handle a missing version comparator',
  scope
)

package.loaded[health_module] = original_health_module
package.loaded[repository_module] = original_repository_module
vim.health = original_vim_health
config.setup({})
h.cleanup_dir(persist_dir)

print('hlcraft health: OK')
