local h = require('tests.helpers')
local scope = 'hlcraft neovim'

local neovim = require('hlcraft.neovim')

local function version_api(version, ge)
  return setmetatable({ ge = ge }, {
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

local supported, current_version = neovim.supports_minimum()
h.assert_true(supported, 'current Neovim was reported as unsupported', scope)
h.assert_true(current_version ~= nil, 'current Neovim version was not returned', scope)
h.assert_equal(neovim.minimum_version, '0.10.0', 'minimum version changed', scope)

local old_version = setmetatable({ major = 0, minor = 9, patch = 5 }, {
  __tostring = function()
    return '0.9.5'
  end,
})

with_version(
  version_api(old_version, function()
    return false
  end),
  function()
    local old_supported, version = neovim.supports_minimum()
    h.assert_true(not old_supported, 'old Neovim version was accepted', scope)
    h.assert_true(version == old_version, 'unsupported version was not returned', scope)
    h.assert_equal(
      neovim.requirement_message(version),
      'requires Neovim >= 0.10.0. Current version: 0.9.5',
      'unsupported version message changed',
      scope
    )
  end
)

with_version(version_api(old_version, nil), function()
  local no_ge_supported, version = neovim.supports_minimum()
  h.assert_true(not no_ge_supported, 'missing version comparator was accepted', scope)
  h.assert_true(version == old_version, 'version without comparator was not returned', scope)
end)

with_version(false, function()
  local no_version_supported, version = neovim.supports_minimum()
  h.assert_true(not no_version_supported, 'missing version API was accepted', scope)
  h.assert_true(version == nil, 'missing version API returned a version', scope)
end)
h.assert_equal(neovim.requirement_message(nil), 'requires Neovim >= 0.10.0', 'missing version message changed', scope)

print('hlcraft neovim: OK')
