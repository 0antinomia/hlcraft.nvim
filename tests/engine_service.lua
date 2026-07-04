local h = require('tests.helpers')
local scope = 'hlcraft engine service'

local engine = require('hlcraft.engine.service')
local store = require('hlcraft.engine.store')

local function with_entry_state(fn)
  local original_draft = vim.deepcopy(store.data.draft)
  local original_persisted = vim.deepcopy(store.data.persisted)

  local ok, err = xpcall(fn, debug.traceback)

  store.data.draft = original_draft
  store.data.persisted = original_persisted

  if not ok then
    error(err, 0)
  end
end

with_entry_state(function()
  h.assert_true(next(engine.get('HlcraftEngineServiceMissing')) == nil, 'missing draft entry was not empty', scope)
  h.assert_true(
    next(engine.get_persisted('HlcraftEngineServiceMissing')) == nil,
    'missing persisted entry was not empty',
    scope
  )

  store.data.draft.HlcraftEngineServiceBrokenDraft = false
  local bad_draft_ok = pcall(engine.get, 'HlcraftEngineServiceBrokenDraft')
  h.assert_true(not bad_draft_ok, 'engine service accepted invalid draft entry', scope)

  store.data.persisted.HlcraftEngineServiceBrokenPersisted = false
  local bad_persisted_ok = pcall(engine.get_persisted, 'HlcraftEngineServiceBrokenPersisted')
  h.assert_true(not bad_persisted_ok, 'engine service accepted invalid persisted entry', scope)
end)

print('hlcraft engine service: OK')
