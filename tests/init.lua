local h = require('tests.helpers')
local scope = 'hlcraft init'

local hlcraft_module = 'hlcraft'
local neovim_module = 'hlcraft.neovim'
local notify_module = 'hlcraft.notify'
local overrides_module = 'hlcraft.engine.service'
local ui_module = 'hlcraft.ui'

local originals = {
  hlcraft = package.loaded[hlcraft_module],
  neovim = package.loaded[neovim_module],
  notify = package.loaded[notify_module],
  overrides = package.loaded[overrides_module],
  ui = package.loaded[ui_module],
}

local function restore_modules()
  package.loaded[hlcraft_module] = originals.hlcraft
  package.loaded[neovim_module] = originals.neovim
  package.loaded[notify_module] = originals.notify
  package.loaded[overrides_module] = originals.overrides
  package.loaded[ui_module] = originals.ui
end

local ok, err = xpcall(function()
  local notifications = {}
  local opened = 0
  local bootstrapped = 0

  package.loaded[hlcraft_module] = nil
  package.loaded[neovim_module] = {
    supports_minimum = function()
      return false, '0.9.5'
    end,
    requirement_message = function(version)
      return 'unsupported ' .. tostring(version)
    end,
  }
  package.loaded[notify_module] = {
    error = function(message)
      notifications[#notifications + 1] = message
    end,
  }
  package.loaded[overrides_module] = {
    bootstrap = function()
      bootstrapped = bootstrapped + 1
    end,
  }
  package.loaded[ui_module] = {
    open = function()
      opened = opened + 1
    end,
  }

  local hlcraft = require(hlcraft_module)
  h.assert_true(not hlcraft.is_setup(), 'unsupported setup started initialized', scope)
  hlcraft.open()
  h.assert_true(not hlcraft.is_setup(), 'unsupported open marked setup complete', scope)
  h.assert_equal(opened, 0, 'unsupported open called UI open', scope)
  h.assert_equal(bootstrapped, 0, 'unsupported open bootstrapped overrides', scope)
  h.assert_equal(notifications[1], 'unsupported 0.9.5', 'unsupported open did not notify version error', scope)
end, debug.traceback)

restore_modules()

if not ok then
  error(err, 0)
end

print('hlcraft init: OK')
