local h = require('tests.helpers')
local scope = 'hlcraft workspace split'

local workspace = require('hlcraft.ui.workspace')
local window = require('hlcraft.ui.workspace.window')
local buffer = require('hlcraft.ui.workspace.buffer')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')

local function assert_function(module, name)
  h.assert_equal(type(module[name]), 'function', ('%s is not exported as a function'):format(name), scope)
end

for _, name in ipairs({
  'is_valid_buf',
  'is_valid_win',
  'get_win',
  'is_open',
  'capture_workspace_window',
  'release_workspace_window',
}) do
  assert_function(window, name)
  h.assert_equal(workspace[name], window[name], ('facade does not reuse window.%s'):format(name), scope)
end

for _, name in ipairs({
  'toggle_help',
  'open',
  'hide',
  'close',
  'cleanup',
}) do
  assert_function(lifecycle, name)
  h.assert_equal(workspace[name], lifecycle[name], ('facade does not reuse lifecycle.%s'):format(name), scope)
end

assert_function(window, 'restore_origin')
assert_function(window, 'restore_all_workspace_windows')
assert_function(window, 'apply_window_options')
assert_function(buffer, 'ensure')

for _, path in ipairs({
  'lua/hlcraft/ui/workspace/window.lua',
  'lua/hlcraft/ui/workspace/buffer.lua',
  'lua/hlcraft/ui/workspace/lifecycle.lua',
}) do
  local content = h.read_file(vim.fn.getcwd() .. '/' .. path)
  h.assert_true(not content:find("require%('hlcraft%.ui%.workspace'%)"), path .. ' imports the workspace facade', scope)
end

local ui_files = vim.fn.glob(vim.fn.getcwd() .. '/lua/hlcraft/ui/**/*.lua', false, true)
for _, path in ipairs(ui_files) do
  local relative = path:sub(#vim.fn.getcwd() + 2)
  if relative ~= 'lua/hlcraft/ui/workspace.lua' then
    local content = h.read_file(path)
    h.assert_true(
      not content:find("require%('hlcraft%.ui%.workspace'%)"),
      relative .. ' imports the workspace facade',
      scope
    )
  end
end

print('hlcraft workspace split: OK')
