local h = require('tests.helpers')
local scope = 'hlcraft engine mutations'

local mutations = require('hlcraft.engine.mutations')
local store = require('hlcraft.engine.store')

local function with_draft_state(fn)
  local original_draft = vim.deepcopy(store.data.draft)
  local original_draft_groups = vim.deepcopy(store.data.draft_groups)
  local original_active = vim.deepcopy(store.data.active)

  local ok, err = xpcall(fn, debug.traceback)

  store.data.draft = original_draft
  store.data.draft_groups = original_draft_groups
  store.data.active = original_active

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
  local name = 'HlcraftEngineMutationsToggleFalse'
  vim.api.nvim_set_hl(0, name, { bold = true })

  local ok, value, err = mutations.toggle_style(name, 'bold')
  h.assert_true(ok, err or 'toggle_style failed', scope)
  h.assert_equal(value, false, 'toggle_style hid a successful false value', scope)
  h.assert_equal(store.data.draft[name].bold, false, 'toggle_style did not persist false override', scope)
end)

print('hlcraft engine mutations: OK')
