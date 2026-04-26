local h = require('tests.helpers')
local scope = 'hlcraft ui theme'

vim.cmd('runtime plugin/hlcraft.lua')

local hlcraft = require('hlcraft')
local ui = require('hlcraft.ui')
local input_model = require('hlcraft.ui.input.model')
local results_state = require('hlcraft.ui.state.results')

local persist_dir = h.temp_dir('hlcraft-ui-theme')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  preview_key = false,
})

local disallowed = {
  Normal = true,
  Comment = true,
  Function = true,
  Title = true,
}

local function collect_token(token, groups)
  if type(token) == 'table' and type(token[2]) == 'string' then
    groups[token[2]] = true
  end
end

local function collect_virt_lines(virt_lines, groups)
  for _, line in ipairs(virt_lines or {}) do
    for _, token in ipairs(line or {}) do
      collect_token(token, groups)
    end
  end
end

local function collect_extmark_groups(buf, ns)
  local groups = {}
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  for _, mark in ipairs(marks) do
    local details = mark[4] or {}
    if type(details.hl_group) == 'string' then
      groups[details.hl_group] = true
    end
    for _, token in ipairs(details.virt_text or {}) do
      collect_token(token, groups)
    end
    collect_virt_lines(details.virt_lines, groups)
  end
  return groups
end

local function assert_ui_private_groups(groups, label)
  for name, _ in pairs(groups) do
    h.assert_true(not disallowed[name], label .. ' inherited external highlight group ' .. name, scope)
    h.assert_true(not name:match('^Hlcraft'), label .. ' used public-style highlight group ' .. name, scope)
    h.assert_true(
      name:match('^@hlcraft%.ui%.') ~= nil or name:match('^hlcraft_ui_') ~= nil,
      label .. ' used non-private UI highlight group ' .. name,
      scope
    )
  end
end

local function assert_theme_groups_are_direct(instance, groups)
  for name, _ in pairs(groups) do
    if name:match('^@hlcraft%.ui%.') then
      local spec = vim.api.nvim_get_hl(instance.ns, { name = name })
      h.assert_true(spec ~= nil and not vim.tbl_isempty(spec), name .. ' was not defined in UI namespace', scope)
      h.assert_true(spec.link == nil, name .. ' links to another highlight group', scope)
    end
  end
end

local function assert_window_base_groups_are_direct(instance)
  for _, name in ipairs({ 'Normal', 'NormalFloat', 'FloatBorder' }) do
    local spec = vim.api.nvim_get_hl(instance.ns, { name = name })
    h.assert_true(spec ~= nil and not vim.tbl_isempty(spec), name .. ' was not defined in UI namespace', scope)
    h.assert_true(spec.link == nil, name .. ' links to another highlight group', scope)
  end
end

vim.api.nvim_set_hl(0, 'HlcraftUiThemeTarget', { fg = '#112233', bg = '#ddeeff' })
hlcraft.open({ instance_name = 'ui-theme-test' })
local instance = ui.get_instance('ui-theme-test')
h.assert_true(
  instance.state.buf and vim.api.nvim_buf_is_valid(instance.state.buf),
  'workspace buffer is invalid',
  scope
)
assert_window_base_groups_are_direct(instance)

local workspace_groups = collect_extmark_groups(instance.state.buf, instance.ns)
assert_ui_private_groups(workspace_groups, 'workspace')
assert_theme_groups_are_direct(instance, workspace_groups)

input_model.fill_input(instance, 'name', 'HlcraftUiThemeTarget', true)
input_model.sync_queries_from_buffer(instance)
instance:rerender()
h.assert_true(#instance.state.results == 1, 'theme target result was not found', scope)
local target_line = h.find_result_line(instance, 1)
h.assert_true(target_line ~= nil, 'theme target result line was not found', scope)
vim.api.nvim_win_set_cursor(vim.fn.bufwinid(instance.state.buf), { target_line, 0 })
results_state.open_detail(instance)

local detail_groups = collect_extmark_groups(instance.state.buf, instance.ns)
assert_ui_private_groups(detail_groups, 'detail')
assert_theme_groups_are_direct(instance, detail_groups)

require('hlcraft.ui.help').toggle(instance)
h.assert_true(
  instance.state.help_buf and vim.api.nvim_buf_is_valid(instance.state.help_buf),
  'help buffer is invalid',
  scope
)
local help_groups = collect_extmark_groups(instance.state.help_buf, instance.ns)
assert_ui_private_groups(help_groups, 'help')
assert_theme_groups_are_direct(instance, help_groups)

local theme = require('hlcraft.ui.theme')
local dark_palette = theme.palette('dark')
h.assert_equal(dark_palette.accent, '#5fb3a5', 'dark accent color drifted', scope)
h.assert_equal(dark_palette.dirty, '#d49a57', 'dark dirty color drifted', scope)
local light_palette = theme.palette('light')
h.assert_equal(light_palette.accent, '#2f6f66', 'light accent color drifted', scope)
h.assert_equal(light_palette.dirty, '#9a5d18', 'light dirty color drifted', scope)

require('hlcraft.ui.workspace').close(instance)
vim.fn.delete(persist_dir, 'rf')
print('hlcraft ui theme: OK')
