local h = require('tests.helpers')
local scope = 'hlcraft ui unsaved prompt'

local prompt = require('hlcraft.ui.scene.unsaved_prompt')

local instance = {
  state = {
    unsaved_prompt = {},
  },
}

prompt.open(instance, 'HlcraftUiUnsavedPrompt', function() end)

local buf = instance.state.unsaved_prompt.buf
local win = instance.state.unsaved_prompt.win
h.assert_true(vim.api.nvim_buf_is_valid(buf), 'prompt buffer was not created', scope)
h.assert_true(vim.api.nvim_win_is_valid(win), 'prompt window was not created', scope)
h.assert_equal(
  table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
  table.concat(prompt.lines, '\n'),
  'prompt lines changed',
  scope
)

local mappings = {}
for _, item in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
  mappings[item.lhs] = true
end
for _, lhs in ipairs({ 's', 'd', 'c', 'q', '<Esc>' }) do
  h.assert_true(mappings[lhs], ('missing prompt mapping %s'):format(lhs), scope)
end

prompt.close(instance)
h.assert_true(instance.state.unsaved_prompt.buf == nil, 'prompt buffer handle was not cleared', scope)
h.assert_true(instance.state.unsaved_prompt.win == nil, 'prompt window handle was not cleared', scope)
h.assert_true(not vim.api.nvim_buf_is_valid(buf), 'prompt buffer was not deleted', scope)

print('hlcraft ui unsaved prompt: OK')
