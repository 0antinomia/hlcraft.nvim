local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local M = {}

M.data = store.data
M.color_keys = store.color_keys
M.style_keys = store.style_keys
M.numeric_keys = store.numeric_keys
M.override_keys = store.override_keys

M.deepcopy = snapshot.deepcopy
M.rebuild_active = snapshot.rebuild_active
M.refresh_base_specs = snapshot.refresh_base_specs
M.compact_entry = snapshot.compact_entry
M.ensure_draft_group = snapshot.ensure_draft_group
M.ensure_runtime_group = snapshot.ensure_runtime_group
M.known_groups = snapshot.known_groups
M.remove_empty_draft_entry = snapshot.remove_empty_draft_entry
M.remove_empty_runtime_entry = snapshot.remove_empty_runtime_entry

return M
