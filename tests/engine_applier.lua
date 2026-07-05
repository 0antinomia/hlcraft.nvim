local h = require('tests.helpers')
local scope = 'hlcraft engine applier'
local assert_fails = h.scoped_assert_fails(scope)

local applier = require('hlcraft.engine.applier')
local config = require('hlcraft.config')
local store = require('hlcraft.engine.store')

local original_set_hl = vim.api.nvim_set_hl
local original_store_set_hl = store.data.original_set_hl
local original_config = config.config
local original_hooked = store.data.hooked
local original_group = store.data.group
local original_pending = vim.deepcopy(store.data.pending)
local original_base_specs = vim.deepcopy(store.data.base_specs)
local original_active = vim.deepcopy(store.data.active)

local function restore_state()
  if vim.api.nvim_set_hl ~= original_set_hl then
    vim.api.nvim_set_hl = original_set_hl
  end
  store.data.original_set_hl = original_store_set_hl
  config.config = original_config
  store.data.hooked = original_hooked
  store.data.group = original_group
  store.data.pending = original_pending
  store.data.base_specs = original_base_specs
  store.data.active = original_active
end

local ok, err = xpcall(function()
  local name = 'HlcraftEngineApplierPending'
  local missing_apply_name_ok = pcall(applier.apply_group, nil)
  h.assert_true(not missing_apply_name_ok, 'applier accepted missing highlight name', scope)
  local empty_apply_name_ok = pcall(applier.apply_group, '')
  h.assert_true(not empty_apply_name_ok, 'applier accepted empty highlight name', scope)

  store.data.original_set_hl = function() end
  store.data.hooked = false
  store.data.pending = {
    [name] = true,
  }
  store.data.base_specs = {}
  store.data.active = {}

  applier.install_pending_hook()
  local invalid_spec_ok = pcall(vim.api.nvim_set_hl, 0, name, nil)
  h.assert_true(not invalid_spec_ok, 'pending hook accepted nil highlight spec', scope)
  h.assert_true(store.data.base_specs[name] == nil, 'pending hook captured nil spec as a base spec', scope)

  local valid_spec = {
    fg = '#101010',
  }
  vim.api.nvim_set_hl(0, name, valid_spec)
  h.assert_equal(store.data.base_specs[name].fg, '#101010', 'pending hook did not capture valid base spec', scope)
  h.assert_true(store.data.base_specs[name] ~= valid_spec, 'pending hook kept mutable base spec reference', scope)

  config.config = vim.tbl_deep_extend('force', vim.deepcopy(config.config), {
    reapply_events = {
      enabled = true,
      events = {
        [2] = 'ColorScheme',
      },
    },
  })
  local sparse_events_ok = pcall(applier.register_reapply_events, function() end)
  h.assert_true(not sparse_events_ok, 'applier accepted sparse reapply events', scope)

  config.config = vim.tbl_deep_extend('force', vim.deepcopy(config.config), {
    reapply_events = {
      enabled = true,
      events = {
        'ColorScheme',
      },
    },
  })
  assert_fails(function()
    applier.register_reapply_events(nil)
  end, 'applier accepted missing replay callback')
end, debug.traceback)

restore_state()

if not ok then
  error(err, 0)
end

print('hlcraft engine applier: OK')
