local M = {}

M.from_none = {
  enabled = false,
  scope = 'extended',
}

M.reapply_events = {
  enabled = true,
  events = {
    'ColorScheme',
  },
}

M.dynamic = {
  enabled = false,
  interval_ms = 80,
}

M.values = {
  from_none = M.from_none,
  threshold = 100,
  include_sp_in_color_search = false,
  persist_dir = vim.fn.stdpath('config') .. '/hlcraft',
  reapply_events = M.reapply_events,
  dynamic = M.dynamic,
  debounce_ms = 100,
  preview_key = 'z',
}

M.known_keys = {}
for key, _ in pairs(M.values) do
  M.known_keys[key] = true
end

return M
