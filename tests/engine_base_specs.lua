local h = require('tests.helpers')
local scope = 'hlcraft engine base specs'

local base_specs = require('hlcraft.engine.base_specs')

local name = 'HlcraftEngineBaseSpecs'
vim.api.nvim_set_hl(0, name, { fg = '#112233', bold = true, underdashed = true })

local normalized = base_specs.normalized_set_hl_spec(name)
h.assert_equal(normalized.fg, '#112233', 'normalized fg changed', scope)
h.assert_equal(normalized.bold, true, 'normalized style changed', scope)
h.assert_equal(normalized.underdashed, true, 'normalized extended style changed', scope)
h.assert_equal(normalized.italic, nil, 'inactive style leaked into normalized spec', scope)
h.assert_true(base_specs.group_exists(name), 'existing group was not detected', scope)
h.assert_true(not base_specs.group_exists('HlcraftEngineMissingBaseSpecs'), 'missing group was detected', scope)

local state = {
  base_specs = {},
  active = {
    [name] = {
      fg = '#abcdef',
      italic = true,
      blend = 12,
    },
  },
}

local merged = base_specs.merged(state, name)
h.assert_true(state.base_specs[name] ~= nil, 'base spec was not captured', scope)
h.assert_equal(merged.fg, '#abcdef', 'active fg override was not merged', scope)
h.assert_equal(merged.bold, true, 'base style was not preserved during merge', scope)
h.assert_equal(merged.underdashed, true, 'base extended style was not preserved during merge', scope)
h.assert_equal(merged.italic, true, 'active style override was not merged', scope)
h.assert_equal(merged.blend, 12, 'active numeric override was not merged', scope)

vim.api.nvim_set_hl(0, name, { fg = '#445566', italic = true })
base_specs.restore(state, name)
local restored = vim.api.nvim_get_hl(0, { name = name, create = false })
h.assert_equal(restored.fg, tonumber('112233', 16), 'restore did not recover captured fg', scope)
h.assert_equal(restored.bold, true, 'restore did not recover captured style', scope)
h.assert_true(restored.italic ~= true, 'restore kept later style mutation', scope)

print('hlcraft engine base specs: OK')
