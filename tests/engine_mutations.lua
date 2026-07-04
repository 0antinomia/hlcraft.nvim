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

local nil_name_ok = pcall(mutations.apply_patch, nil, { fg = '#ffffff' })
h.assert_true(not nil_name_ok, 'mutation accepted nil highlight name', scope)
local empty_name_ok = pcall(mutations.toggle_style, '', 'bold')
h.assert_true(not empty_name_ok, 'mutation accepted empty highlight name', scope)

with_draft_state(function()
  local name = 'HlcraftEngineMutationsToggleFalse'
  vim.api.nvim_set_hl(0, name, { bold = true })

  local ok, value, err = mutations.toggle_style(name, 'bold')
  h.assert_true(ok, err or 'toggle_style failed', scope)
  h.assert_equal(value, false, 'toggle_style hid a successful false value', scope)
  h.assert_equal(store.data.draft[name].bold, false, 'toggle_style did not persist false override', scope)
end)

print('hlcraft engine mutations: OK')
