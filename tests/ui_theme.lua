local h = require('tests.helpers')
local scope = 'hlcraft ui theme'

local theme = require('hlcraft.ui.theme')

local ns = vim.api.nvim_create_namespace('hlcraft-ui-theme-test')
local non_numeric_ns_ok = pcall(theme.apply, false)
h.assert_true(not non_numeric_ns_ok, 'theme accepted non-numeric namespace', scope)
local infinite_ns_ok = pcall(theme.apply, math.huge)
h.assert_true(not infinite_ns_ok, 'theme accepted infinite namespace', scope)
theme.apply(ns)
for _, group_name in ipairs({
  theme.groups.section,
  theme.groups.hint,
  theme.groups.hint_action,
  theme.groups.value,
  theme.groups.key,
  theme.groups.title,
}) do
  h.assert_true(type(group_name) == 'string' and group_name ~= '', 'missing visual hierarchy group', scope)
  local applied = vim.api.nvim_get_hl(ns, { name = group_name })
  h.assert_true(applied.fg ~= nil, ('theme group %s has no foreground'):format(group_name), scope)
end
local hint_hl = vim.api.nvim_get_hl(ns, { name = theme.groups.hint })
local action_hl = vim.api.nvim_get_hl(ns, { name = theme.groups.hint_action })
h.assert_true(action_hl.fg ~= hint_hl.fg, 'hint actions should contrast with muted hint text', scope)

print('hlcraft ui theme: OK')
