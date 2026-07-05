local h = require('tests.helpers')
local scope = 'hlcraft engine snapshot'

local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local function with_group_state(fn)
  local original_draft = vim.deepcopy(store.data.draft)
  local original_draft_groups = vim.deepcopy(store.data.draft_groups)
  local original_persisted_groups = vim.deepcopy(store.data.persisted_groups)

  local ok, err = xpcall(fn, debug.traceback)

  store.data.draft = original_draft
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

  store.data.draft_groups.Spaced = ' snapshot '
  snapshot.ensure_draft_group('Spaced')
  h.assert_equal(store.data.draft_groups.Spaced, 'snapshot', 'draft group was not normalized', scope)

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

with_group_state(function()
  store.data.persisted_groups = {
    Persisted = ' shared ',
  }
  store.data.draft_groups = {
    Draft = 'draft',
    Same = 'shared',
  }

  local known = snapshot.known_groups()
  h.assert_equal(known[1], 'draft', 'known groups did not include normalized draft group', scope)
  h.assert_equal(known[2], 'shared', 'known groups did not normalize and deduplicate groups', scope)

  store.data.draft_groups.BadKnown = false
  local invalid_known_ok = pcall(snapshot.known_groups)
  h.assert_true(not invalid_known_ok, 'snapshot known groups accepted invalid draft group', scope)
end)

local dynamic_spec = {
  version = 1,
  preset = 'pulse',
  timeline = {
    { at = 0, color = 'base' },
    { at = 1, color = '#ffffff' },
  },
}

local raw_entry = {
  fg = '#ABCDEF',
  dynamic = {
    fg = dynamic_spec,
  },
}
local normalized_entry = snapshot.normalize_draft_entry(raw_entry)
h.assert_equal(normalized_entry.fg, '#abcdef', 'draft entry color was not normalized', scope)
h.assert_equal(normalized_entry.dynamic.fg.preset, 'pulse', 'draft entry dynamic was not normalized', scope)
h.assert_equal(raw_entry.fg, '#ABCDEF', 'draft entry normalization mutated input', scope)
h.assert_true(snapshot.normalize_draft_entry(nil) == nil, 'nil draft entry did not normalize to nil', scope)
h.assert_true(snapshot.normalize_draft_entry({}) == nil, 'empty draft entry did not normalize to nil', scope)

local invalid_entry_ok = pcall(snapshot.normalize_draft_entry, false)
h.assert_true(not invalid_entry_ok, 'snapshot accepted a non-table draft entry', scope)
local unknown_field_ok = pcall(snapshot.normalize_draft_entry, { unknown = true })
h.assert_true(not unknown_field_ok, 'snapshot accepted an unknown draft entry field', scope)
local invalid_dynamic_ok = pcall(snapshot.normalize_draft_entry, {
  dynamic = {
    fg = {
      version = 1,
      timeline = {},
    },
  },
})
h.assert_true(not invalid_dynamic_ok, 'snapshot accepted an invalid draft dynamic override', scope)

with_group_state(function()
  store.data.draft.EmptyDraftEntry = {}
  store.data.draft_groups.EmptyDraftEntry = 'draft'

  snapshot.remove_empty_draft_entry('EmptyDraftEntry')
  h.assert_true(store.data.draft.EmptyDraftEntry == nil, 'empty draft entry was not removed', scope)
  h.assert_true(store.data.draft_groups.EmptyDraftEntry == nil, 'empty draft entry group was not removed', scope)
end)

print('hlcraft engine snapshot: OK')
