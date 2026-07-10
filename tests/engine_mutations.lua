local h = require('tests.helpers')
local scope = 'hlcraft engine mutations'

local applier = require('hlcraft.engine.applier')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local mutations = require('hlcraft.engine.mutations')
local store = require('hlcraft.engine.store')
local timers = require('hlcraft.core.timers')

local function with_draft_state(fn)
  local original_set_hl = vim.api.nvim_set_hl
  local original_store_set_hl = store.data.original_set_hl
  local original_dynamic_runtime = dynamic_runtime.capture()
  local original_hooked = store.data.hooked
  local original_draft = vim.deepcopy(store.data.draft)
  local original_draft_groups = vim.deepcopy(store.data.draft_groups)
  local original_active = vim.deepcopy(store.data.active)
  local original_pending = vim.deepcopy(store.data.pending)
  local original_base_specs = vim.deepcopy(store.data.base_specs)

  local ok, err = xpcall(fn, debug.traceback)

  applier.uninstall_pending_hook()
  if vim.api.nvim_set_hl ~= original_set_hl then
    vim.api.nvim_set_hl = original_set_hl
  end
  store.data.original_set_hl = original_store_set_hl
  dynamic_runtime.restore(original_dynamic_runtime)
  store.data.hooked = original_hooked
  store.data.draft = original_draft
  store.data.draft_groups = original_draft_groups
  store.data.active = original_active
  store.data.pending = original_pending
  store.data.base_specs = original_base_specs

  if not ok then
    error(err, 0)
  end
end

with_draft_state(function()
  store.data.draft.HlcraftEngineMutationsBroken = false
  local invalid_draft_ok = pcall(mutations.apply_patch, 'HlcraftEngineMutationsBroken', {
    fg = '#ffffff',
  })
  h.assert_true(not invalid_draft_ok, 'mutation replaced invalid draft entry', scope)
  h.assert_equal(
    store.data.draft.HlcraftEngineMutationsBroken,
    false,
    'invalid draft entry changed after rejected mutation',
    scope
  )
end)

with_draft_state(function()
  local name = 'HlcraftEngineMutationsInvalidDynamic'
  store.data.draft[name] = {
    fg = '#111111',
    dynamic = {
      fg = {
        version = 1,
        timeline = {},
      },
    },
  }
  store.data.draft_groups[name] = 'mutations'
  local before_entry = vim.deepcopy(store.data.draft[name])
  local before_group = store.data.draft_groups[name]

  local invalid_dynamic_ok = pcall(mutations.apply_patch, name, {
    bg = '#ffffff',
  })
  h.assert_true(not invalid_dynamic_ok, 'mutation accepted invalid existing draft dynamic state', scope)
  h.assert_true(
    vim.deep_equal(store.data.draft[name], before_entry),
    'invalid existing dynamic state changed after rejected mutation',
    scope
  )
  h.assert_equal(
    store.data.draft_groups[name],
    before_group,
    'invalid existing dynamic state changed draft group after rejected mutation',
    scope
  )
end)

with_draft_state(function()
  local name = 'HlcraftEngineMutationsNormalizeDraft'
  store.data.draft[name] = {
    fg = '#ABCDEF',
  }
  store.data.draft_groups[name] = 'old'

  local ok, err = mutations.apply_patch(name, { group = 'new' })
  h.assert_true(ok, err or 'group mutation failed', scope)
  h.assert_equal(store.data.draft[name].fg, '#abcdef', 'group mutation did not normalize draft entry', scope)
  h.assert_equal(store.data.draft_groups[name], 'new', 'group mutation changed wrong group', scope)
end)

with_draft_state(function()
  local name = 'HlcraftEngineMutationsApplyFailure'
  vim.api.nvim_set_hl(0, name, { fg = '#101010' })
  store.data.draft[name] = {
    fg = '#111111',
  }
  store.data.draft_groups[name] = 'old'
  store.data.active = vim.deepcopy(store.data.draft)
  store.data.base_specs[name] = false
  store.data.pending[name] = true
  local before_draft = vim.deepcopy(store.data.draft)
  local before_draft_groups = vim.deepcopy(store.data.draft_groups)
  local before_active = vim.deepcopy(store.data.active)
  local before_pending = vim.deepcopy(store.data.pending)

  local apply_failure_ok = pcall(mutations.apply_patch, name, { bg = '#222222' })
  h.assert_true(not apply_failure_ok, 'mutation accepted failed highlight apply', scope)
  h.assert_true(vim.deep_equal(store.data.draft, before_draft), 'failed apply changed draft state', scope)
  h.assert_true(
    vim.deep_equal(store.data.draft_groups, before_draft_groups),
    'failed apply changed draft group state',
    scope
  )
  h.assert_true(vim.deep_equal(store.data.active, before_active), 'failed apply changed active state', scope)
  h.assert_true(vim.deep_equal(store.data.pending, before_pending), 'failed apply changed pending state', scope)
end)

with_draft_state(function()
  local name = 'HlcraftEngineMutationsSetHlFailure'
  vim.api.nvim_set_hl(0, name, { fg = '#101010' })
  store.data.original_set_hl = function()
    error('set hl failed')
  end
  store.data.draft[name] = {
    fg = '#111111',
  }
  store.data.draft_groups[name] = 'old'
  store.data.active = vim.deepcopy(store.data.draft)
  store.data.base_specs = {}
  store.data.pending = {}
  local before_draft = vim.deepcopy(store.data.draft)
  local before_draft_groups = vim.deepcopy(store.data.draft_groups)
  local before_active = vim.deepcopy(store.data.active)
  local before_pending = vim.deepcopy(store.data.pending)

  local set_hl_failure_ok = h.with_notify_stub(function()
    return pcall(mutations.apply_patch, name, { bg = '#222222' })
  end)
  h.assert_true(not set_hl_failure_ok, 'mutation accepted failed set_hl application', scope)
  h.assert_true(vim.deep_equal(store.data.draft, before_draft), 'failed set_hl changed draft state', scope)
  h.assert_true(
    vim.deep_equal(store.data.draft_groups, before_draft_groups),
    'failed set_hl changed draft group state',
    scope
  )
  h.assert_true(vim.deep_equal(store.data.active, before_active), 'failed set_hl changed active state', scope)
  h.assert_true(vim.deep_equal(store.data.pending, before_pending), 'failed set_hl changed pending state', scope)
end)

with_draft_state(function()
  local name = 'HlcraftEngineMutationsDynamicStartFailure'
  vim.api.nvim_set_hl(0, name, { fg = '#101010' })
  store.data.original_set_hl = vim.api.nvim_set_hl
  store.data.draft[name] = {
    fg = '#111111',
  }
  store.data.draft_groups[name] = 'old'
  store.data.active = vim.deepcopy(store.data.draft)
  store.data.base_specs = {}
  store.data.pending = {}
  local before_draft = vim.deepcopy(store.data.draft)
  local before_draft_groups = vim.deepcopy(store.data.draft_groups)
  local before_active = vim.deepcopy(store.data.active)
  local before_pending = vim.deepcopy(store.data.pending)
  local before_hl = vim.api.nvim_get_hl(0, { name = name, create = false })
  local original_repeating = timers.repeating
  timers.repeating = function()
    return nil
  end

  local dynamic_start_failure_ok = pcall(mutations.apply_patch, name, {
    fg = '#222222',
    dynamic = {
      fg = {
        version = 1,
        duration = 1000,
        loop = 'repeat',
        timeline = {
          { at = 0, color = 'base' },
          { at = 1, color = '#ffffff' },
        },
      },
    },
  })
  timers.repeating = original_repeating

  h.assert_true(not dynamic_start_failure_ok, 'mutation accepted failed dynamic timer start', scope)
  h.assert_true(vim.deep_equal(store.data.draft, before_draft), 'failed dynamic timer start changed draft state', scope)
  h.assert_true(
    vim.deep_equal(store.data.draft_groups, before_draft_groups),
    'failed dynamic timer start changed draft group state',
    scope
  )
  h.assert_true(
    vim.deep_equal(store.data.active, before_active),
    'failed dynamic timer start changed active state',
    scope
  )
  h.assert_true(
    vim.deep_equal(store.data.pending, before_pending),
    'failed dynamic timer start changed pending state',
    scope
  )
  local restored_hl = vim.api.nvim_get_hl(0, { name = name, create = false })
  h.assert_equal(restored_hl.fg, before_hl.fg, 'failed dynamic timer start changed the live highlight', scope)
  h.assert_true(dynamic_runtime.base_spec(name) == nil, 'failed dynamic timer start kept runtime task', scope)
end)

with_draft_state(function()
  local name = 'HlcraftEngineMutationsDynamicFrameRollback'
  vim.api.nvim_set_hl(0, name, { fg = '#000000' })
  store.data.original_set_hl = vim.api.nvim_set_hl
  store.data.draft[name] = {
    dynamic = {
      fg = {
        version = 1,
        duration = 1000,
        loop = 'repeat',
        timeline = {
          { at = 0, color = 'base' },
          { at = 1, color = '#ffffff' },
        },
      },
    },
  }
  store.data.draft_groups[name] = 'old'
  store.data.active = vim.deepcopy(store.data.draft)
  store.data.base_specs = {}
  store.data.pending = {}
  applier.apply_group(name)
  dynamic_runtime.tick(500)
  local before = vim.api.nvim_get_hl(0, { name = name, create = false })
  store.data.original_set_hl = function(ns, applied_name, spec)
    if applied_name == name and spec and spec.bg == '#222222' then
      error('patch apply failed')
    end
    return vim.api.nvim_set_hl(ns, applied_name, spec)
  end
  local mutation_ok = h.with_notify_stub(function()
    return pcall(mutations.apply_patch, name, { bg = '#222222' })
  end)
  store.data.original_set_hl = vim.api.nvim_set_hl
  local task = dynamic_runtime.base_spec(name)
  local after = vim.api.nvim_get_hl(0, { name = name, create = false })
  dynamic_runtime.clear_group(name, { fg = '#000000' })
  h.assert_true(not mutation_ok, 'mutation accepted a failed dynamic patch', scope)
  h.assert_true(task ~= nil, 'failed dynamic patch dropped the runtime task', scope)
  h.assert_equal(after.fg, before.fg, 'failed dynamic patch changed the captured live frame', scope)
end)

local nil_name_ok = pcall(mutations.apply_patch, nil, { fg = '#ffffff' })
h.assert_true(not nil_name_ok, 'mutation accepted nil highlight name', scope)
local empty_name_ok = pcall(mutations.toggle_style, '', 'bold')
h.assert_true(not empty_name_ok, 'mutation accepted empty highlight name', scope)
local invalid_toggle_key_ok, _, invalid_toggle_key_err = mutations.toggle_style('Normal', nil)
h.assert_true(not invalid_toggle_key_ok, 'mutation accepted nil style key', scope)
h.assert_equal(invalid_toggle_key_err, 'Unsupported style key: nil', 'nil style key error changed', scope)
local color_toggle_key_ok, _, color_toggle_key_err = mutations.toggle_style('Normal', 'fg')
h.assert_true(not color_toggle_key_ok, 'mutation accepted color field as style key', scope)
h.assert_equal(color_toggle_key_err, 'Unsupported style key: fg', 'color style key error changed', scope)

with_draft_state(function()
  local name = 'HlcraftEngineMutationsToggleFalse'
  vim.api.nvim_set_hl(0, name, { bold = true })

  local ok, value, err = mutations.toggle_style(name, 'bold')
  h.assert_true(ok, err or 'toggle_style failed', scope)
  h.assert_equal(value, false, 'toggle_style hid a successful false value', scope)
  h.assert_equal(store.data.draft[name].bold, false, 'toggle_style did not persist false override', scope)
end)

print('hlcraft engine mutations: OK')
