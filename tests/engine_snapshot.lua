local h = require('tests.helpers')
local scope = 'hlcraft engine snapshot'

local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local function with_group_state(fn)
  local original_draft_groups = vim.deepcopy(store.data.draft_groups)
  local original_persisted_groups = vim.deepcopy(store.data.persisted_groups)

  local ok, err = xpcall(fn, debug.traceback)

  store.data.draft_groups = original_draft_groups
  store.data.persisted_groups = original_persisted_groups

  if not ok then
    error(err, 0)
  end
end

with_group_state(function()
  store.data.draft_groups = {
    Explicit = 'draft',
  }
  store.data.persisted_groups = {
    Inherited = 'persisted',
  }

  snapshot.ensure_draft_group('Explicit')
  h.assert_equal(store.data.draft_groups.Explicit, 'draft', 'explicit draft group changed', scope)

  snapshot.ensure_draft_group('Inherited')
  h.assert_equal(store.data.draft_groups.Inherited, 'persisted', 'persisted group was not inherited', scope)

  snapshot.ensure_draft_group('Missing')
  h.assert_true(store.data.draft_groups.Missing == nil, 'missing persisted group created a draft group', scope)

  store.data.draft_groups.BadDraft = 1
  local bad_draft_ok = pcall(snapshot.ensure_draft_group, 'BadDraft')
  h.assert_true(not bad_draft_ok, 'snapshot accepted numeric draft group', scope)

  store.data.draft_groups.EmptyDraft = ' '
  local empty_draft_ok = pcall(snapshot.ensure_draft_group, 'EmptyDraft')
  h.assert_true(not empty_draft_ok, 'snapshot accepted empty draft group', scope)

  store.data.persisted_groups.BadPersisted = 1
  local bad_persisted_ok = pcall(snapshot.ensure_draft_group, 'BadPersisted')
  h.assert_true(not bad_persisted_ok, 'snapshot accepted numeric persisted group', scope)
end)

print('hlcraft engine snapshot: OK')
